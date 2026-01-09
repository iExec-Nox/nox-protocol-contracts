import assert from "node:assert/strict";
import { describe, it } from "node:test";
import hre from "hardhat";
import ACLModule from "../../ignition/modules/ACL.js";
import { keccak256, toHex } from "viem";

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
    const [ownerWallet, unauthorizedWallet] = await viem.getWalletClients();

    return {
      acl,
      teeComputeManager,
      ownerWallet,
      unauthorizedWallet
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
});
