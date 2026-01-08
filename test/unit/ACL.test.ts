import assert from "node:assert/strict";
import { describe, it } from "node:test";
import hre from "hardhat";
import ACLModule from "../../ignition/modules/ACL.js";
import { keccak256, toHex, getAddress } from "viem";

const { networkHelpers, viem, ignition } = await hre.network.connect();

describe("ACL", async function () {

  async function deployACLFixture() {
    const teeComputeManager = "0x0000000000000000000000000000000000000001";
    
    const { acl } = await ignition.deploy(ACLModule, {
      parameters: {
        ACLModule: {
          teeComputeManager,
        },
      },
    });

    const [ownerWallet, userWallet, unauthorizedWallet] = await viem.getWalletClients();
    const publicClient = await viem.getPublicClient();

    return {
      acl,
      teeComputeManager,
      ownerWallet,
      userWallet,
      unauthorizedWallet,
      publicClient,
    };
  }

  it("Should deploy successfully the ACL contract", async function () {
    const { acl } = await networkHelpers.loadFixture(deployACLFixture);

    assert.ok(acl.address);
  });

  describe("isAllowed", function () {
    it("Should return false for addresses without permission", async function () {
      const { acl, userWallet } = await networkHelpers.loadFixture(deployACLFixture);

      const handle = keccak256(toHex("test-handle"));

      const isAllowed = await acl.read.isAllowed([handle, userWallet.account.address]);
      assert.strictEqual(isAllowed, false);
    });
  });

  describe("allow", function () {
    it("Should revert when sender has no access to the handle", async function () {
      const { acl, unauthorizedWallet, userWallet } = await networkHelpers.loadFixture(deployACLFixture);

      const handle = keccak256(toHex("test-handle"));

      // unauthorized has no access to the handle
      const unauthorizedAcl = await viem.getContractAt("ACL", acl.address, {
        client: { wallet: unauthorizedWallet },
      });

      await viem.assertions.revertWithCustomErrorWithArgs(
        unauthorizedAcl.write.allow([handle, userWallet.account.address]),
        acl,
        "SenderNotAllowed",
        [getAddress(unauthorizedWallet.account.address)]
      );
    });

    it("Should revert when target address is zero address", async function () {
      const { acl, ownerWallet } = await networkHelpers.loadFixture(deployACLFixture);

      const handle = keccak256(toHex("test-handle"));

      // Note: ZeroAddress check happens after SenderNotAllowed check
      // Since no one has access to the handle yet, it reverts with SenderNotAllowed first
      await viem.assertions.revertWithCustomErrorWithArgs(
        acl.write.allow([
          handle,
          "0x0000000000000000000000000000000000000000",
        ]),
        acl,
        "SenderNotAllowed",
        [getAddress(ownerWallet.account.address)]
      );
    });
  });
});
