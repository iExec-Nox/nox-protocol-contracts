import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Address } from "viem";
import { upgradeNoxCompute } from "../../scripts/upgrade/upgrade.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";
import { loadFixture } from "../utils/fixture.ts";

describe("[IT] Upgrade", function () {
    describe("NoxCompute Upgrade", function () {
        it("Should swap NoxCompute proxy implementation and preserve state", async function () {
            const { noxCompute, gateway } = await loadFixture();
            const viem = connection.viem;

            // A fresh deploy is already at the latest INITIALIZER_VERSION, so the upgrade's
            // `reinitialize()` would revert. Roll the on-chain initializer version back by one to
            // simulate an existing proxy on an older version.
            await _decrementInitializedVersion(noxCompute.address);

            await upgradeNoxCompute(noxCompute.address, false, "NoxComputeUpgradeMock");
            const upgraded = await viem.getContractAt("NoxComputeUpgradeMock", noxCompute.address);
            const isUpgradeMock = await upgraded.read.isUpgradeMock();
            assert.strictEqual(isUpgradeMock, true, "Proxy should delegate to the upgraded implementation");

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

            const newImpl = await viem.deployContract("NoxComputeUpgradeMock", []);

            await assert.rejects(
                noxCompute.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when caller lacks UPGRADER_ROLE",
            );
        });
    });
});

/**
 * Rolls the on-chain `_initialized` version of a proxy back by one, simulating a proxy that
 * sits on an older version so an upgrade's `reinitialize()` has a version gap to consume.
 */
async function _decrementInitializedVersion(proxyAddress: Address): Promise<void> {
    // ERC-7201 storage location of OZ `Initializable`; low 8 bytes hold `_initialized`.
    const INITIALIZABLE_SLOT = "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00";
    const publicClient = await connection.viem.getPublicClient();
    const current = BigInt(
        (await publicClient.getStorageAt({ address: proxyAddress, slot: INITIALIZABLE_SLOT })) ?? "0x0",
    );
    assert.ok(current > 0n, "Expected proxy to be initialized (initialized version > 0)");
    await connection.networkHelpers.setStorageAt(proxyAddress, INITIALIZABLE_SLOT, current - 1n);
}
