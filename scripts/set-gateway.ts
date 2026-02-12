import { readFile } from "fs/promises";
import { join } from "path";
import connection from "./utils/hardhat-connection-singleton.ts";

// Script to set the gateway address on the NoxCompute contract.
// It reads the deployed contract address from ignition deployment artifacts.
// Requires GATEWAY_ADDRESS environment variable to be set.

/**
 * Sets the gateway address on the NoxCompute contract.
 * @param printLogs whether to print logs or not
 */
export async function setGateway(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    // Use owner wallet (first account when running with PRIVATE_KEY set to owner key)
    const ownerClient = walletClients[0];
    if (!ownerClient) {
        throw new Error("No owner wallet available. Set PRIVATE_KEY environment variable.");
    }

    const gatewayAddress = process.env.GATEWAY_ADDRESS;
    if (!gatewayAddress) {
        throw new Error("GATEWAY_ADDRESS environment variable is required");
    }

    _log(`Setting gateway address: ${gatewayAddress}`);
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

    // Set the gateway address
    const txHash = await noxCompute.write.setGateway([gatewayAddress as `0x${string}`]);
    _log(`Transaction hash: ${txHash}`);

    await publicClient.waitForTransactionReceipt({ hash: txHash });
    _log("Gateway address set successfully");

    // Verify the gateway was set correctly
    const currentGateway = await noxCompute.read.gateway();
    _log(`Current gateway: ${currentGateway}`);

    if (currentGateway.toLowerCase() !== gatewayAddress.toLowerCase()) {
        throw new Error(`Gateway address mismatch: expected ${gatewayAddress}, got ${currentGateway}`);
    }
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    await setGateway();
}

function _isHardhatRunCommand() {
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/set-gateway.ts");
}
