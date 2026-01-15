import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { keccak256, toHex } from "viem";
import { loadFixture } from "../utils/fixture.js";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";

describe("ACL", function () {
    describe("Deployment", function () {
        it("Should deploy successfully", async function () {
            const { acl } = await loadFixture();
            assert.ok(acl.address);
        });
    });

    describe("isAllowed", function () {
        it("Should return false for addresses without permission", async function () {
            const { acl, wallet1: unauthorizedWallet } = await loadFixture();
            const handle = keccak256(toHex("test-handle"));
            const isAllowed = await acl.read.isAllowed([handle, unauthorizedWallet.account.address]);
            assert.strictEqual(isAllowed, false);
        });
    });

    describe("Transient vs Persistent permissions", function () {
        it("Should clear transient permissions after transaction while persistent remain", async function () {
            const { wallet0 } = await loadFixture();
            const viem = connection.viem;
            const networkHelpers = connection.networkHelpers;

            // Deploy ACLMock for this test
            const aclMock = await viem.deployContract("ACLMock");

            const handleTransient = keccak256(toHex("handle-transient"));
            const handlePersistent = keccak256(toHex("handle-persistent"));

            // Single transaction: Grant transient to one handle and persistent to another (same account)
            // This uses the mock helper to do both in the same transaction
            // The ACLMock contract itself is the teeComputeManager, so we use wallet0 to call it
            await aclMock.write.grantTransientAndPersistent([
                handleTransient,
                handlePersistent,
                wallet0.account.address,
            ]);

            // Mine a new block to further verify persistence
            await networkHelpers.mine();

            // New transaction: Check permissions - transient should be gone, persistent should remain
            const aclAddress = await aclMock.read.acl();
            const aclContract = await viem.getContractAt("ACL", aclAddress);

            const isAllowedTransient = await aclContract.read.isAllowed([handleTransient, wallet0.account.address]);
            const isAllowedPersistent = await aclContract.read.isAllowed([handlePersistent, wallet0.account.address]);

            // Transient permission should be cleared after the transaction
            assert.strictEqual(isAllowedTransient, false, "Transient permission should be cleared after tx");
            // Persistent permission should remain
            assert.strictEqual(isAllowedPersistent, true, "Persistent permission should remain");
        });
    });
});
