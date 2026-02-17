import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.ts";
import { upgradeACL } from "../../scripts/upgrade-acl.ts";
import { upgradeNoxCompute } from "../../scripts/upgrade-nox-compute.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

describe("[IT] Upgrade", function () {
    describe("ACL Upgrade", function () {
        it("Should upgrade ACL proxy to V2 implementation", async function () {
            const { acl } = await loadFixture();
            const viem = connection.viem;

            // Upgrade using the upgrade script
            await upgradeACL(acl.address, false);

            // Verify upgrade: version() should return 2
            const aclV2 = await viem.getContractAt("ACLV2Mock", acl.address);
            const version = await aclV2.read.version();
            assert.strictEqual(version, 2n, "ACL version should be 2 after upgrade");

            // Verify existing state is preserved after upgrade
            const owner = await aclV2.read.owner();
            assert.strictEqual(
                owner.toLowerCase(),
                (await acl.read.owner()).toLowerCase(),
                "Owner should be preserved after upgrade",
            );
        });

        it("Should revert when non-owner tries to upgrade ACL", async function () {
            const { acl, wallet1 } = await loadFixture();
            const viem = connection.viem;

            const newImpl = await viem.deployContract("ACLV2Mock", []);

            await assert.rejects(
                acl.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when non-owner tries to upgrade",
            );
        });
    });

    describe("NoxCompute Upgrade", function () {
        it("Should upgrade NoxCompute proxy to V2 implementation", async function () {
            const { acl, noxCompute, gateway } = await loadFixture();
            const viem = connection.viem;

            // Upgrade using the upgrade script
            await upgradeNoxCompute(noxCompute.address, acl.address, false);

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

            const aclAddress = await noxComputeV2.read.ACL();
            assert.strictEqual(
                aclAddress.toLowerCase(),
                acl.address.toLowerCase(),
                "ACL address should be preserved after upgrade",
            );
        });

        it("Should revert when non-owner tries to upgrade NoxCompute", async function () {
            const { acl, noxCompute, wallet1 } = await loadFixture();
            const viem = connection.viem;

            const newImpl = await viem.deployContract("NoxComputeV2Mock", [acl.address]);

            await assert.rejects(
                noxCompute.write.upgradeToAndCall([newImpl.address, "0x"], { account: wallet1.account }),
                "Should revert when non-owner tries to upgrade",
            );
        });
    });
});
