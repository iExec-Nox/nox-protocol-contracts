import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { keccak256, toHex } from "viem";
import { loadFixture } from "../utils/fixture.js";

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
});
