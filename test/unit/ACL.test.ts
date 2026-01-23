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

    describe("Transient & Persistent permissions", function () {
        it("Should clear transient permissions after transaction while persistent remain", async function () {
            const { teeComputeManager, wallet1 } = await loadFixture();
            const viem = connection.viem;
            const networkHelpers = connection.networkHelpers;
            const handleTransient = keccak256(toHex("handle-transient"));
            const handlePersistent = keccak256(toHex("handle-persistent"));

            // Single transaction: Grant transient to one handle and persistent to another (same account)
            await teeComputeManager.write.grantTransientAndPersistent([
                handleTransient,
                handlePersistent,
                wallet1.account.address,
            ]);

            // Mine a new block to further verify persistence
            await networkHelpers.mine();

            // New transaction: Check permissions - transient should be gone, persistent should remain
            const aclAddress = await teeComputeManager.read.acl();
            const aclContract = await viem.getContractAt("ACL", aclAddress);

            const isAllowedTransient = await aclContract.read.isAllowed([handleTransient, wallet1.account.address]);
            const isAllowedPersistent = await aclContract.read.isAllowed([handlePersistent, wallet1.account.address]);

            assert.strictEqual(isAllowedTransient, false, "Transient permission should be cleared after tx");
            assert.strictEqual(isAllowedPersistent, true, "Persistent permission should remain");
        });
    });
});
