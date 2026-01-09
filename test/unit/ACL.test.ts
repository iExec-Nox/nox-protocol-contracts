import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import ACLModule from "../../ignition/modules/ACL.js";

describe("ACL", async function () {
    const { ignition } = await network.connect();

    it("Should deploy successfully the ACL contract", async function () {
        const { acl } = await ignition.deploy(ACLModule);

        assert.ok(acl.address);
    });
});
