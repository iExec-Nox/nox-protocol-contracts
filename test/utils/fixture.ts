import { rmSync } from "node:fs";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { deploy } from "../../scripts/deploy.ts";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";

export async function loadFixture() {
    return await connection.networkHelpers.loadFixture(deployFixture);
}

/**
 * This function defines the fixture to deploy for tests. Update this function when needed.
 */
async function deployFixture() {
    const viem = connection.viem;
    const publicClient = await viem.getPublicClient();
    // On a fresh chain (e.g. after services:down/up), delete any stale Ignition journal
    // so Ignition always starts from a clean state instead of trying to resume a
    // broken deployment from a previous run.
    const noxComputeAddress = process.env.NOX_COMPUTE_CONTRACT as `0x${string}` | undefined;
    if (noxComputeAddress) {
        const code = await publicClient.getCode({ address: noxComputeAddress });
        if (!code || code === "0x") {
            rmSync("ignition/deployments/localhost", { recursive: true, force: true });
        }
    }
    // disable deployment logging for tests (more readable logs)
    const deployment = await deploy(false);
    const accounts = await viem.getWalletClients();
    const gateway = privateKeyToAccount(generatePrivateKey());
    const tx = await deployment.noxCompute.write.setGateway([gateway.address]);
    await publicClient.waitForTransactionReceipt({ hash: tx });
    return {
        ...deployment,
        admin: accounts[0],
        wallet1: accounts[1],
        wallet2: accounts[2],
        wallet3: accounts[3],
        wallet4: accounts[4],
        gateway,
    };
}
