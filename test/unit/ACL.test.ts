import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { keccak256, toHex } from "viem";
import { loadFixture } from "../utils/fixture.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

describe("ACL", function () {
    describe("Transient & Persistent permissions", function () {
        it("Should clear transient permissions after transaction while persistent remain", async function () {
            const { acl, wallet1 } = await loadFixture();
            const viem = connection.viem;
            // Deploy NoxComputeMock with ACL address
            const noxComputeMock = await viem.deployContract("NoxComputeMock", [acl.address]);
            // Set noxComputeMock in the ACL
            await acl.write.setNoxCompute([noxComputeMock.address]);
            const handleTransient = keccak256(toHex("handle-transient"));
            const handlePersistent = keccak256(toHex("handle-persistent"));

            // Single transaction: Grant transient to one handle and persistent to another (same account)
            await noxComputeMock.write.grantTransientAndPersistent([
                handleTransient,
                handlePersistent,
                wallet1.account.address,
            ]);

            // Mine a new block to further verify persistence
            await connection.networkHelpers.mine();

            // New transaction: Check permissions - transient should be gone, persistent should remain
            const aclAddress = await noxComputeMock.read.ACL();
            const aclContract = await viem.getContractAt("ACL", aclAddress);

            const isAllowedTransient = await aclContract.read.isAllowed([handleTransient, wallet1.account.address]);
            const isAllowedPersistent = await aclContract.read.isAllowed([handlePersistent, wallet1.account.address]);

            assert.strictEqual(isAllowedTransient, false, "Transient permission should be cleared after tx");
            assert.strictEqual(isAllowedPersistent, true, "Persistent permission should remain");
        });
    });
});
