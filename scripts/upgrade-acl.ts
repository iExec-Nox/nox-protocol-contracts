import { readFile } from "fs/promises";
import { join } from "path";
import { deploy } from "./deploy.ts";
import connection from "./utils/hardhat-connection-singleton.ts";

// Script to upgrade the ACL proxy to a new implementation.
// It reads the deployed proxy address from ignition deployment artifacts,
// deploys the new implementation, and calls upgradeToAndCall on the proxy.
//
// When running on a local (edr-simulated) network, a fresh deployment is performed first
// since each `hardhat run` starts a clean chain.
//
// Usage: `hardhat run scripts/upgrade-acl.ts --network <network-name>`

/**
 * Upgrades the ACL proxy to a new implementation.
 * @param printLogs whether to print logs or not
 * @returns The new implementation address
 */
export async function upgradeACL(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    const ownerClient = walletClients[0];
    if (!ownerClient) {
        throw new Error("No owner wallet available. Set PRIVATE_KEY environment variable.");
    }

    // TODO: Replace with the actual new ACL contract name
    const contractName = "ACLV2Mock";

    _log(`Upgrading ACL proxy`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Using owner address: ${ownerClient.account.address}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    const aclProxyAddress = await _resolveACLProxyAddress(_log);
    _log(`ACL proxy address: ${aclProxyAddress}`);

    // Deploy new implementation
    const newImplementation = await viem.deployContract(contractName, [], {
        client: { wallet: ownerClient },
    });
    _log(`New implementation deployed at: ${newImplementation.address}`);

    // Upgrade the proxy via UUPS upgradeToAndCall
    const proxy = await viem.getContractAt(contractName, aclProxyAddress, {
        client: { wallet: ownerClient },
    });
    const txHash = await proxy.write.upgradeToAndCall([newImplementation.address, "0x"]);
    _log(`Upgrade transaction hash: ${txHash}`);

    await publicClient.waitForTransactionReceipt({ hash: txHash });
    _log("ACL proxy upgraded successfully");

    return newImplementation.address;
}

/**
 * Resolves the ACL proxy address.
 * On local (edr-simulated) networks, deploys contracts first since each
 * `hardhat run` starts a fresh chain with no prior state.
 * On remote networks, reads from ignition deployment artifacts.
 */
async function _resolveACLProxyAddress(_log: (...args: unknown[]) => void): Promise<string> {
    if (connection.networkConfig.type === "edr-simulated") {
        _log("Local network detected, deploying contracts first...");
        const { acl } = await deploy(false);
        return acl.address;
    }

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

    const aclProxyAddress = deployedAddresses["ACL#proxy"];
    if (!aclProxyAddress) {
        throw new Error("ACL#proxy not found in deployment artifacts");
    }

    return aclProxyAddress;
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    await upgradeACL();
}

function _isHardhatRunCommand() {
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/upgrade-acl.ts");
}
