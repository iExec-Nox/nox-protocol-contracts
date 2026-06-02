import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";
import connection from "./utils/hardhat-connection-singleton.ts";
import { getChainConfig } from "../config/config.ts";

// Script to set the KMS public key on the NoxCompute contract.
// It reads the deployed contract address from ignition deployment artifacts
// and the KMS public key from `config/config.ts`.

/**
 * Sets the KMS public key on the NoxCompute contract.
 * @param printLogs whether to print logs or not
 */
export async function setKmsPublicKey(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    const upgraderClient = walletClients[0];
    if (!upgraderClient) {
        throw new Error("No upgrader wallet available. Set PRIVATE_KEY to the UPGRADER_ROLE key.");
    }

    const { kmsPublicKey } = getChainConfig(connection.networkName);

    _log(`Setting KMS public key: ${kmsPublicKey}`);
    _log(`Using upgrader address: ${upgraderClient.account.address}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    // Read NoxCompute proxy address from ignition deployment artifacts
    const noxComputeAddress = await readDeployedAddress("NoxCompute#proxy");

    _log(`NoxCompute address: ${noxComputeAddress}`);

    // Get NoxCompute contract instance with upgrader wallet
    const noxCompute = await viem.getContractAt("NoxCompute", noxComputeAddress, {
        client: { wallet: upgraderClient },
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
