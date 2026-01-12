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

        // Deploy ACLMock for testing transient/persistent in two different transactions
        const aclMock = await viem.deployContract("ACLMock");

        return {
            acl,
            aclMock,
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
            const { aclMock, teeComputeManager, ownerWallet } = await networkHelpers.loadFixture(deployACLFixture);

            const handleTransient = keccak256(toHex("handle-transient"));
            const handlePersistent = keccak256(toHex("handle-persistent"));

            // Single transaction: Grant transient to one handle and persistent to another (same account)
            // This uses the mock helper to do both in the same transaction
            await aclMock.write.grantTransientAndPersistent(
                [handleTransient, handlePersistent, ownerWallet.account.address],
                {
                    account: teeComputeManager.account,
                },
            );

            // Mine a new block to further verify persistence
            await networkHelpers.mine();

            // New transaction: Check permissions - transient should be gone, persistent should remain
            const acl = aclMock.read.acl();
            const aclAddress = await acl;
            const aclContract = await viem.getContractAt("ACL", aclAddress);

            const isAllowedTransient = await aclContract.read.isAllowed([handleTransient, ownerWallet.account.address]);
            const isAllowedPersistent = await aclContract.read.isAllowed([
                handlePersistent,
                ownerWallet.account.address,
            ]);

            // Transient permission should be cleared after the transaction
            assert.strictEqual(isAllowedTransient, false, "Transient permission should be cleared after tx");
            // Persistent permission should remain
            assert.strictEqual(isAllowedPersistent, true, "Persistent permission should remain");
        });
    });
});
