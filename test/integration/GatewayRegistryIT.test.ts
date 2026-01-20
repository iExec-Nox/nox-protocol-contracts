import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { loadFixture } from "../utils/fixture.js";

describe("[IT] GatewayRegistry", function () {
    it("Should register and remove gateway successfully", async function () {
        const { gatewayRegistry, wallet0: admin } = await loadFixture();
        const gatewayAddress = "0x1234567890123456789012345678901234567890";
        const defaultAdminRoleId = await gatewayRegistry.read.DEFAULT_ADMIN_ROLE();
        const gatewayRoleId = await gatewayRegistry.read.GATEWAY_ROLE();
        const hasDefaultAdminRole = (address: `0x${string}`) =>
            gatewayRegistry.read.hasRole([defaultAdminRoleId, address]);
        const hasGatewayRole = (address: `0x${string}`) => gatewayRegistry.read.hasRole([gatewayRoleId, address]);
        // Check initial state
        assert.strictEqual(true, await hasDefaultAdminRole(admin.account.address));
        assert.strictEqual(false, await hasGatewayRole(gatewayAddress));
        // Grant GATEWAY_ROLE to Gateway address
        await gatewayRegistry.write.grantRole([gatewayRoleId, gatewayAddress], {
            account: admin.account,
        });
        assert.strictEqual(true, await hasGatewayRole(gatewayAddress));
        // Revoke GATEWAY_ROLE from Gateway address
        await gatewayRegistry.write.revokeRole([gatewayRoleId, gatewayAddress], {
            account: admin.account,
        });
        assert.strictEqual(false, await hasGatewayRole(gatewayAddress));
    });
});
