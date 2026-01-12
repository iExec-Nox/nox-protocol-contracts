import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import GatewayRegistryModule from "../../ignition/modules/GatewayRegistry.js";

describe("GatewayRegistry", async function () {
    const { ignition } = await network.connect();

    it("Should deploy successfully", async function () {
        const { gatewayRegistry } = await ignition.deploy(GatewayRegistryModule);
        assert.ok(gatewayRegistry.address);
    });
});
