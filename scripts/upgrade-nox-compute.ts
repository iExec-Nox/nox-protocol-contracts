import { readFile } from "fs/promises";
import { join } from "path";
import connection from "./utils/hardhat-connection-singleton.ts";

// Script to upgrade the NoxCompute proxy to a new implementation.
// It reads the deployed proxy and ACL addresses from ignition deployment artifacts,
// deploys the new implementation (with ACL as constructor arg), and calls upgradeToAndCall on the proxy.
//
// Usage: `hardhat run scripts/upgrade-nox-compute.ts --network <network-name>`

/**
 * Upgrades the NoxCompute proxy to a new implementation.
 * @param printLogs whether to print logs or not
 * @returns The new implementation address
 */
export async function upgradeNoxCompute(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    const ownerClient = walletClients[0];
    if (!ownerClient) {
        throw new Error("No owner wallet available. Set PRIVATE_KEY environment variable.");
    }

    // TODO: Replace with the actual new NoxCompute contract name
    const contractName = "NoxComputeV2Mock";

    _log(`Upgrading NoxCompute proxy`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Using owner address: ${ownerClient.account.address}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    // Read addresses from ignition deployment artifacts
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

    const noxComputeProxyAddress = deployedAddresses["NoxCompute#proxy"];
    if (!noxComputeProxyAddress) {
        throw new Error("NoxCompute#proxy not found in deployment artifacts");
    }

    const aclProxyAddress = deployedAddresses["ACL#proxy"];
    if (!aclProxyAddress) {
        throw new Error("ACL#proxy not found in deployment artifacts");
    }

    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);
    _log(`ACL proxy address: ${aclProxyAddress}`);

    // Deploy new implementation with ACL address as constructor arg
    const newImplementation = await viem.deployContract(contractName, [aclProxyAddress], {
        client: { wallet: ownerClient },
    });
    _log(`New implementation deployed at: ${newImplementation.address}`);

    // Upgrade the proxy via UUPS upgradeToAndCall
    const proxy = await viem.getContractAt(contractName, noxComputeProxyAddress, {
        client: { wallet: ownerClient },
    });
    const txHash = await proxy.write.upgradeToAndCall([newImplementation.address, "0x"]);
    _log(`Upgrade transaction hash: ${txHash}`);

    await publicClient.waitForTransactionReceipt({ hash: txHash });
    _log("NoxCompute proxy upgraded successfully");

    return newImplementation.address;
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    await upgradeNoxCompute();
}

function _isHardhatRunCommand() {
    return (
        process.argv.length >= 4 &&
        process.argv[2] === "run" &&
        process.argv[3].includes("scripts/upgrade-nox-compute.ts")
    );
}
