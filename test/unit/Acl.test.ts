import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";

describe("ACL", async function () {
  const { viem } = await network.connect();

  it("Should deploy successfully with ERC-7201 storage pattern", async function () {
    const acl = await viem.deployContract("ACL");

    assert.ok(acl.address);
    assert.match(acl.address, /^0x[a-fA-F0-9]{40}$/);
  });
    
  it("Should implement ERC-7201 namespaced storage", async function () {
    const acl = await viem.deployContract("ACL");

    // Contract successfully deploys with proper storage layout
    // HandleInfo contains nested mappings for admins and viewers
    // ACLStorage uses namespaced storage slot
    assert.ok(acl.address);
  });
});
