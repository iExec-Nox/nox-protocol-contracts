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

            const newImpl = await viem.deployContract("NoxComputeUpgradeMock", []);

            await assert.rejects(
                noxCompute.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when caller lacks UPGRADER_ROLE",
            );
        });
    });
});
