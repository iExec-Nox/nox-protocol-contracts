import assert from "node:assert/strict";
import { describe, it } from "node:test";
import hre from "hardhat";
import ACLModule from "../../ignition/modules/ACL.js";
import { keccak256, toHex } from "viem";

const { networkHelpers, viem, ignition } = await hre.network.connect();

describe("ACL", async function () {
    async function deployACLFixture() {
        const [ownerWallet, unauthorizedWallet, teeComputeManager] = await viem.getWalletClients();
        // Note: We use teeComputeManager as a wallet (instead of just an address) because we need
        // to impersonate it and send transactions from it in tests

        const { acl } = await ignition.deploy(ACLModule, {
            parameters: {
                ACLModule: {
                    teeComputeManager: teeComputeManager.account.address,
                },
            },
        });

        return {
            acl,
            teeComputeManager: teeComputeManager,
            ownerWallet,
            unauthorizedWallet,
        };
    }

    it("Should deploy successfully the ACL contract", async function () {
        const { acl } = await networkHelpers.loadFixture(deployACLFixture);

        assert.ok(acl.address);
    });

    describe("isAllowed", function () {
        it("Should return false for addresses without permission", async function () {
            const { acl, unauthorizedWallet } = await networkHelpers.loadFixture(deployACLFixture);

            const handle = keccak256(toHex("test-handle"));

            const isAllowed = await acl.read.isAllowed([handle, unauthorizedWallet.account.address]);
            assert.strictEqual(isAllowed, false);
        });
    });

    describe("Transient vs Persistent permissions", function () {
        it("Should clear transient permissions after transaction while persistent remain", async function () {
            const { acl, teeComputeManager, ownerWallet, unauthorizedWallet } =
                await networkHelpers.loadFixture(deployACLFixture);

            const handleTransient = keccak256(toHex("handle-transient"));
            const handlePersistent = keccak256(toHex("handle-persistent"));

            // Transaction 1: Grant transient access to ownerWallet for both handles
            await acl.write.allowTransient([handleTransient, ownerWallet.account.address], {
                account: teeComputeManager.account,
            });

            await acl.write.allowTransient([handlePersistent, ownerWallet.account.address], {
                account: teeComputeManager.account,
            });

            // Transaction 2: Convert one to persistent by granting to unauthorizedWallet
            // ownerWallet still has transient access from previous transaction
            await acl.write.allow([handlePersistent, unauthorizedWallet.account.address], {
                account: ownerWallet.account,
            });

            // Transaction 3: Check permissions - transient from tx1 should be gone
            // Note: Each await creates a new transaction, so transient from tx1 is cleared
            const isAllowedTransient = await acl.read.isAllowed([handleTransient, ownerWallet.account.address]);
            const isAllowedPersistent = await acl.read.isAllowed([
                handlePersistent,
                unauthorizedWallet.account.address,
            ]);

            // Transient permission from transaction 1 should be cleared
            assert.strictEqual(isAllowedTransient, false, "Transient permission should be cleared after tx");

            // Persistent permission should remain
            assert.strictEqual(isAllowedPersistent, true, "Persistent permission should remain");

            // Mine a new block to further verify persistence
            await networkHelpers.mine();

            // Verify persistent permission still exists after mining
            const isAllowedAfterMining = await acl.read.isAllowed([
                handlePersistent,
                unauthorizedWallet.account.address,
            ]);
            assert.strictEqual(isAllowedAfterMining, true, "Persistent permission should remain after mining");

            // Transient should still be cleared
            const isTransientAfterMining = await acl.read.isAllowed([handleTransient, ownerWallet.account.address]);
            assert.strictEqual(isTransientAfterMining, false, "Transient should remain cleared");
        });
    });
});

