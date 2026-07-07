import { getChainConfig } from "../config/config.ts";
import connection from "./utils/hardhat-connection-singleton.ts";
import { isHardhatRunCommand } from "./utils/helpers.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";

// Script to set the gateway address on the NoxCompute contract.
// It reads the deployed contract address from ignition deployment artifacts
// and the gateway address from `config/config.ts`.

/**
 * Sets the gateway address on the NoxCompute contract.
 * @param printLogs whether to print logs or not
 */
export async function setGateway(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    const upgraderClient = walletClients[0];
    if (!upgraderClient) {
        throw new Error("No upgrader wallet available. Set PRIVATE_KEY environment variable.");
    }

    const { gateway: gatewayAddress } = getChainConfig(connection.networkName);

    _log(`Setting gateway address: ${gatewayAddress}`);
    _log(`Using upgrader address: ${upgraderClient.account.address}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    // Read NoxCompute proxy address from ignition deployment artifacts
    const noxComputeAddress = await readDeployedAddress("NoxCompute#proxy");

    _log(`NoxCompute address: ${noxComputeAddress}`);

    // Get NoxCompute contract instance with upgrader wallet
    const noxCompute = await viem.getContractAt("NoxCompute", noxComputeAddress, {
        client: { wallet: upgraderClient },
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
if (isHardhatRunCommand("scripts/set-gateway.ts")) {
    await setGateway();
}
