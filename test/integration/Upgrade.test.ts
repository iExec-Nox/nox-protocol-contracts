import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.ts";
import { upgradeNoxCompute } from "../../scripts/upgrade.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

describe("[IT] Upgrade", function () {
    describe("NoxCompute Upgrade", function () {
        it("Should swap NoxCompute proxy implementation and preserve state", async function () {
            const { noxCompute, gateway } = await loadFixture();
            const viem = connection.viem;

            // Fresh deploys are already initialized up to V3, so we don't pass any reinitializer
            // call here. The OZ plugin upgrades the proxy and runs the new implementation's storage
            // checks.
            await upgradeNoxCompute(noxCompute.address, false, "NoxComputeUpgradeMock");
            const upgraded = await viem.getContractAt("NoxComputeUpgradeMock", noxCompute.address);
            const version = await upgraded.read.version();
            assert.strictEqual(version, 3n, "Sentinel version should be readable after upgrade");

            // Verify existing state is preserved
            const currentGateway = await upgraded.read.gateway();
            assert.strictEqual(
                currentGateway.toLowerCase(),
                gateway.address.toLowerCase(),
                "Gateway address should be preserved after upgrade",
            );
        });

        it("Should revert when non-upgrader tries to upgrade NoxCompute", async function () {
            const { noxCompute, wallet1 } = await loadFixture();
            const viem = connection.viem;

            const newImpl = await viem.deployContract("NoxComputeUpgradeMock", [0]);

            await assert.rejects(
                noxCompute.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when caller lacks UPGRADER_ROLE",
            );
        });

        // Simulates an existing V2 proxy (Ownable-based) being migrated to V3 (AccessControl).
        // We roll the `_initialized` counter back to 2 so the real `reinitializer(3)` path of
        // `initializeV3` runs, then verify the two effects unique to the migration:
        //   - The three AccessControl roles are granted to the addresses passed to initializeV3.
        //   - The legacy Ownable storage slot is cleared.
        // Role enforcement after migration is covered in unit tests (NoxCompute-Admin.t.sol).
        it("Should migrate a V2 proxy to V3 via initializeV3", async function () {
            const { noxCompute, admin, wallet1, wallet2, wallet3 } = await loadFixture();
            const publicClient = await connection.viem.getPublicClient();

            // ERC-7201 slot for `openzeppelin.storage.Initializable`. Force `_initialized = 2`
            // (packed uint64 at offset 0) so the proxy looks like it stopped at V2.
            const INITIALIZABLE_SLOT = "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" as const;
            await connection.networkHelpers.setStorageAt(
                noxCompute.address,
                INITIALIZABLE_SLOT,
                "0x0000000000000000000000000000000000000000000000000000000000000002",
            );
            // Seed the legacy Ownable slot so we can later verify initializeV3 clears it.
            const OWNABLE_SLOT = "0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300" as const;
            await connection.networkHelpers.setStorageAt(
                noxCompute.address,
                OWNABLE_SLOT,
                `0x000000000000000000000000${admin.account.address.slice(2)}`,
            );

            // Upgrade and atomically run initializeV3.
            const newAdmin = wallet1.account.address;
            const newUpgrader = wallet2.account.address;
            const newPaymentManager = wallet3.account.address;
            await upgradeNoxCompute(noxCompute.address, false, "NoxCompute", {
                fn: "initializeV3",
                args: [newAdmin, newUpgrader, newPaymentManager],
            });

            // Effect #1: roles granted to the addresses passed to initializeV3.
            const [DEFAULT_ADMIN_ROLE, UPGRADER_ROLE, PAYMENT_MANAGER_ROLE] = await Promise.all([
                noxCompute.read.DEFAULT_ADMIN_ROLE(),
                noxCompute.read.UPGRADER_ROLE(),
                noxCompute.read.PAYMENT_MANAGER_ROLE(),
            ]);
            assert.strictEqual(await noxCompute.read.hasRole([DEFAULT_ADMIN_ROLE, newAdmin]), true);
            assert.strictEqual(await noxCompute.read.hasRole([UPGRADER_ROLE, newUpgrader]), true);
            assert.strictEqual(await noxCompute.read.hasRole([PAYMENT_MANAGER_ROLE, newPaymentManager]), true);

            // Effect #2: legacy Ownable storage slot cleared.
            const ownableAfter = await publicClient.getStorageAt({
                address: noxCompute.address,
                slot: OWNABLE_SLOT,
            });
            assert.strictEqual(
                ownableAfter,
                "0x0000000000000000000000000000000000000000000000000000000000000000",
                "Ownable storage slot should be cleared after V3 migration",
            );
        });
    });
});
