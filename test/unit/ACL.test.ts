import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import ACLModule from "../../ignition/modules/ACL.js";
import { keccak256, toHex, getAddress } from "viem";

describe("ACL", async function () {
  const { ignition, viem } = await network.connect();

  it("Should deploy successfully the ACL contract", async function () {
    const { acl } = await ignition.deploy(ACLModule);

    assert.ok(acl.address);
  });

  describe("isAllowed", function () {
    it("Should return false for addresses without permission", async function () {
      const { acl } = await ignition.deploy(ACLModule);
      const [owner, user] = await viem.getWalletClients();

      const handle = keccak256(toHex("test-handle"));

      const isAllowed = await acl.read.isAllowed([handle, user.account.address]);
      assert.strictEqual(isAllowed, false);
    });
  });

  describe("allow", function () {
    it("Should revert when sender has no access to the handle", async function () {
      const { acl } = await ignition.deploy(ACLModule);
      const [owner, unauthorized, target] = await viem.getWalletClients();

      const handle = keccak256(toHex("test-handle"));

      // unauthorized has no access to the handle
      const unauthorizedAcl = await viem.getContractAt("ACL", acl.address, {
        client: { wallet: unauthorized },
      });

      await viem.assertions.revertWithCustomErrorWithArgs(
        unauthorizedAcl.write.allow([handle, target.account.address]),
        acl,
        "SenderNotAllowed",
        [getAddress(unauthorized.account.address)]
      );
    });

    it("Should revert when target address is zero address", async function () {
      const { acl } = await ignition.deploy(ACLModule);
      const [owner] = await viem.getWalletClients();

      const handle = keccak256(toHex("test-handle"));

      await viem.assertions.revertWithCustomError(
        acl.write.allow([
          handle,
          "0x0000000000000000000000000000000000000000",
        ]),
        acl,
        "ZeroAddress"
      );
    });
  });
});
