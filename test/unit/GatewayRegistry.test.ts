import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadFixture } from "../helpers/fixture.js";

describe("GatewayRegistry", function () {
    describe("Deployment", function () {
        it("Should deploy successfully", async function () {
            const { gatewayRegistry } = await loadFixture();
            assert.ok(gatewayRegistry.address);
            assert.ok(await gatewayRegistry.read.defaultAdmin());
        });
    });
});
