import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import { deploy } from "../../scripts/deploy.js";

// Module-level cache for the fixture to avoid re-deployment.
// Caching is essential: without it, CREATE2 deployments would fail with address collisions
// since the same salts would be used across tests.
let cachedFixture: Awaited<ReturnType<typeof deployFixture>> | null = null;
let snapshotId: string | null = null;

export async function loadFixture() {
    const publicClient = await connection.viem.getPublicClient();

    // If we have a cached fixture, restore the snapshot and return cached data
    if (cachedFixture && snapshotId) {
        // Revert to snapshot to get clean state
        await publicClient.request({
            method: "evm_revert" as any,
            params: [snapshotId] as any,
        });
        // Take a new snapshot for the next test
        snapshotId = await publicClient.request({
            method: "evm_snapshot" as any,
            params: [] as any,
        });
        return cachedFixture;
    }

    // First call - deploy and cache
    cachedFixture = await deployFixture();
    // Take snapshot after deployment
    snapshotId = await publicClient.request({
        method: "evm_snapshot" as any,
        params: [] as any,
    });
    return cachedFixture;
}

/**
 * Deploys contracts for testing.
 * Uses the main deploy script which produces deterministic addresses via CREATE2.
 * The addresses match those hardcoded in TEEPrimitives.sol.
 */
async function deployFixture() {
    const viem = connection.viem;
    const publicClient = await viem.getPublicClient();
    // disable deployment logging for tests (more readable logs)
    const deployment = await deploy(false);
    const accounts = await viem.getWalletClients();
    const gateway = privateKeyToAccount(generatePrivateKey());
    const tx = await deployment.teeComputeManager.write.setGateway([gateway.address]);
    await publicClient.waitForTransactionReceipt({ hash: tx });
    return {
        ...deployment,
        // Accounts
        admin: accounts[0],
        wallet1: accounts[1],
        wallet2: accounts[2],
        wallet3: accounts[3],
        wallet4: accounts[4],
        gateway,
    };
}
