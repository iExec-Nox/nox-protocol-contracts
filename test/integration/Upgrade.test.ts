import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getAddress, zeroAddress } from "viem";
import { loadFixture } from "../utils/fixture.ts";
import { upgradeNoxCompute } from "../../scripts/upgrade.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

describe("[IT] Upgrade", function () {
    describe("NoxCompute Upgrade", function () {
        it("Should upgrade NoxCompute proxy to V2 implementation", async function () {
            const { noxCompute, gateway } = await loadFixture();
            const viem = connection.viem;

            // Fresh deploys are already initialized up to V3, so we don't pass any reinitializer
            // call here. The OZ plugin upgrades the proxy and runs the new implementation's storage
            // checks.
            await upgradeNoxCompute(noxCompute.address, false, "NoxComputeV2Mock");
            const noxComputeV2 = await viem.getContractAt("NoxComputeV2Mock", noxCompute.address);
            const version = await noxComputeV2.read.version();
            assert.strictEqual(version, 2n, "NoxCompute version should be 2 after upgrade");

            // Verify existing state is preserved
            const currentGateway = await noxComputeV2.read.gateway();
            assert.strictEqual(
                currentGateway.toLowerCase(),
                gateway.address.toLowerCase(),
                "Gateway address should be preserved after upgrade",
            );
        });

        it("Should revert when non-upgrader tries to upgrade NoxCompute", async function () {
            const { noxCompute, wallet1 } = await loadFixture();
            const viem = connection.viem;

            const newImpl = await viem.deployContract("NoxComputeV2Mock", [0]);

            await assert.rejects(
                noxCompute.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when caller lacks UPGRADER_ROLE",
            );
        });

        // Simulates an existing V2 proxy (Ownable-based) being upgraded to V3 (AccessControl).
        // We rewrite the proxy's `_initialized` slot down to version 2 so we can exercise the
        // real `reinitializer(3)` path of `initializeV3`. After the upgrade we check that:
        //   - The three roles are granted to the addresses passed to initializeV3.
        //   - The legacy Ownable storage slot has been cleared.
        //   - The proxy is functional under the new role model (only UPGRADER can setGateway
        //     and upgrade, only PAYMENT_MANAGER can manage licenses).
        it("Should migrate a V2 proxy to V3 via initializeV3", async function () {
            const { noxCompute, admin, wallet1, wallet2, wallet3 } = await loadFixture();
            const viem = connection.viem;
            const publicClient = await viem.getPublicClient();

            // Roll the Initializable version back to 2 to simulate a proxy stuck at V2.
            //
            // ERC-7201 location for `openzeppelin.storage.Initializable`:
            //   bytes32(uint256(keccak256("openzeppelin.storage.Initializable")) - 1) & ~bytes32(uint256(0xff))
            const INITIALIZABLE_SLOT = "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" as const;
            // Storage layout in InitializableStorage:
            //   uint64 _initialized;   // packed at offset 0
            //   bool   _initializing;  // packed at offset 8
            // We force `_initialized = 2`, `_initializing = false`.
            await connection.networkHelpers.setStorageAt(
                noxCompute.address,
                INITIALIZABLE_SLOT,
                "0x0000000000000000000000000000000000000000000000000000000000000002",
            );

            // Also seed the legacy Ownable slot with a sentinel value so we can verify it gets cleared.
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

            // Verify role grants.
            const DEFAULT_ADMIN_ROLE = await noxCompute.read.DEFAULT_ADMIN_ROLE();
            const UPGRADER_ROLE = await noxCompute.read.UPGRADER_ROLE();
            const PAYMENT_MANAGER_ROLE = await noxCompute.read.PAYMENT_MANAGER_ROLE();
            assert.strictEqual(
                await noxCompute.read.hasRole([DEFAULT_ADMIN_ROLE, newAdmin]),
                true,
                "newAdmin should have DEFAULT_ADMIN_ROLE",
            );
            assert.strictEqual(
                await noxCompute.read.hasRole([UPGRADER_ROLE, newUpgrader]),
                true,
                "newUpgrader should have UPGRADER_ROLE",
            );
            assert.strictEqual(
                await noxCompute.read.hasRole([PAYMENT_MANAGER_ROLE, newPaymentManager]),
                true,
                "newPaymentManager should have PAYMENT_MANAGER_ROLE",
            );

            // Verify the legacy Ownable slot is cleared.
            const ownableAfter = await publicClient.getStorageAt({
                address: noxCompute.address,
                slot: OWNABLE_SLOT,
            });
            assert.strictEqual(
                ownableAfter,
                "0x0000000000000000000000000000000000000000000000000000000000000000",
                "Ownable storage slot should be cleared after V3 migration",
            );

            // Functional check: only UPGRADER can change the gateway now.
            await assert.rejects(
                noxCompute.write.setGateway([zeroAddress], { account: newAdmin }),
                "Admin without UPGRADER_ROLE should not be able to setGateway",
            );
            const freshGateway = getAddress("0x000000000000000000000000000000000000b0b0");
            const tx = await noxCompute.write.setGateway([freshGateway], { account: newUpgrader });
            await publicClient.waitForTransactionReceipt({ hash: tx });
            assert.strictEqual(
                (await noxCompute.read.gateway()).toLowerCase(),
                freshGateway.toLowerCase(),
                "UPGRADER should be able to setGateway after migration",
            );

            // Functional check: only PAYMENT_MANAGER can manage licenses.
            const licenseOwner = getAddress("0x000000000000000000000000000000000000b1b1");
            const expirationDate = Math.floor(Date.now() / 1000) + 30 * 24 * 3600;
            await assert.rejects(
                noxCompute.write.createLicense([licenseOwner, expirationDate, 1000], {
                    account: newUpgrader,
                }),
                "Upgrader without PAYMENT_MANAGER_ROLE should not createLicense",
            );
            const createTx = await noxCompute.write.createLicense([licenseOwner, expirationDate, 1000], {
                account: newPaymentManager,
            });
            await publicClient.waitForTransactionReceipt({ hash: createTx });
        });
    });
});
