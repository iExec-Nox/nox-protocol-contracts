import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";

describe("[IT] TEEComputeManager", function () {
    it("Should validate input proof", async function () {
        const { teeComputeManager, wallet0, wallet1 } = await loadFixture();
        assert.ok(await teeComputeManager.read.acl());
        // construct proof data
        // const handle = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd";
        // const proof =
        // await teeComputeManager.read.validateProof(handle, proof);
    });
});
