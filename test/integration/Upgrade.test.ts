import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.ts";
import { upgradeNoxCompute } from "../../scripts/upgrade.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

describe("[IT] Upgrade", function () {
    describe("NoxCompute Upgrade", function () {
        it("Should upgrade NoxCompute proxy to V2 implementation", async function () {
            const { noxCompute, gateway } = await loadFixture();
            const viem = connection.viem;

            // Upgrade using the upgrade script
            await upgradeNoxCompute(noxCompute.address, false, "NoxComputeV2Mock");
            // Verify upgrade: version() should return 2
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

        it("Should revert when non-owner tries to upgrade NoxCompute", async function () {
            const { noxCompute, wallet1 } = await loadFixture();
            const viem = connection.viem;

            const newImpl = await viem.deployContract("NoxComputeV2Mock", [0]);

            await assert.rejects(
                noxCompute.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when non-owner tries to upgrade",
            );
        });
    });
});
