import { readFile } from "fs/promises";
import { join } from "path";
import connection from "./utils/hardhat-connection-singleton.ts";

// Script to set the KMS public key on the NoxCompute contract.
// It reads the deployed contract address from ignition deployment artifacts.
// Requires KMS_PUBLIC_KEY environment variable to be set.

/**
 * Sets the KMS public key on the NoxCompute contract.
 * @param printLogs whether to print logs or not
 */
export async function setKmsPublicKey(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    // Use owner wallet (first account when running with PRIVATE_KEY set to owner key)
    const ownerClient = walletClients[0];
    if (!ownerClient) {
        throw new Error("No owner wallet available. Set PRIVATE_KEY environment variable.");
    }

    const kmsPublicKey = process.env.KMS_PUBLIC_KEY;
    if (!kmsPublicKey) {
        throw new Error("KMS_PUBLIC_KEY environment variable is required");
    }

    _log(`Setting KMS public key: ${kmsPublicKey}`);
    _log(`Using owner address: ${ownerClient.account.address}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    // Read NoxCompute proxy address from ignition deployment artifacts
    const deploymentPath = join(
        process.cwd(),
        "ignition",
        "deployments",
        connection.networkName,
        "deployed_addresses.json",
    );

    let deployedAddresses: Record<string, string>;
    try {
        const content = await readFile(deploymentPath, "utf-8");
        deployedAddresses = JSON.parse(content);
    } catch {
        throw new Error(
            `Failed to read deployment artifacts at ${deploymentPath}. ` +
                `Make sure contracts are deployed on ${connection.networkName}.`,
        );
    }

    const noxComputeAddress = deployedAddresses["NoxCompute#proxy"];
    if (!noxComputeAddress) {
        throw new Error("NoxCompute#proxy not found in deployment artifacts");
    }

    _log(`NoxCompute address: ${noxComputeAddress}`);

    // Get NoxCompute contract instance with owner wallet
    const noxCompute = await viem.getContractAt("NoxCompute", noxComputeAddress, {
        client: { wallet: ownerClient },
    });

    // Set the KMS public key
    const txHash = await noxCompute.write.setKmsPublicKey([kmsPublicKey as `0x${string}`]);
    _log(`Transaction hash: ${txHash}`);

    await publicClient.waitForTransactionReceipt({ hash: txHash });
    _log("KMS public key set successfully");

    // Verify the key was set correctly
    const currentKey = await noxCompute.read.kmsPublicKey();
    _log(`Current KMS public key: ${currentKey}`);

    if (currentKey.toLowerCase() !== kmsPublicKey.toLowerCase()) {
        throw new Error(`KMS public key mismatch: expected ${kmsPublicKey}, got ${currentKey}`);
    }
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    await setKmsPublicKey();
}

function _isHardhatRunCommand() {
    return (
        process.argv.length >= 4 &&
        process.argv[2] === "run" &&
        process.argv[3].includes("scripts/set-kms-public-key.ts")
    );
}
