import { deploy } from "../../scripts/deploy.js";
import connection from "../../scripts/utils/ConnectionSingleton.js";

export async function loadFixture() {
    return await connection.networkHelpers.loadFixture(deployFixture);
}

/**
 * This functions defines the fixture to deploy for tests. Update this function when needed.
 */
async function deployFixture() {
    const viem = connection.viem;
    const deployment = await deploy(false); // disable logging for tests
    const [wallet0, wallet1] = await viem.getWalletClients();
    return {
        gatewayRegistry: deployment.gatewayRegistry,
        acl: deployment.acl,
        wallet0,
        wallet1,
    };
}
