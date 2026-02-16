import { deploy } from "./deploy.ts";
import { isFreshLocalNetwork } from "./utils/network.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";
import connection from "./utils/hardhat-connection-singleton.ts";

// Script to upgrade the ACL proxy to a new implementation.
// It reads the deployed proxy address from ignition deployment artifacts,
// deploys the new implementation, and calls upgradeToAndCall on the proxy.
//
// When running on a local (edr-simulated) network, a fresh deployment is performed first
// since each `hardhat run` starts a clean chain.
//
// Usage: `hardhat run scripts/upgrade-acl.ts --network <network-name>`

// TODO: Use @openzeppelin/hardhat-upgrades plugin for upgrade safety checks
// (storage layout validation, implementation compatibility) when it becomes compatible with Hardhat 3.

/**
 * Upgrades the ACL proxy to a new implementation.
 * @param proxyAddress the proxy address to upgrade, resolved automatically if not provided
 * @param printLogs whether to print logs or not
 * @returns The new implementation address
 */
export async function upgradeACL(proxyAddress?: string, printLogs = true) {
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

    const aclProxyAddress = proxyAddress ?? (await _resolveACLProxyAddress(_log));
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
 * On local non-forked (edr-simulated) networks, deploys contracts first since each
 * `hardhat run` starts a fresh chain with no prior state.
 * On remote or forked networks, reads from ignition deployment artifacts.
 */
async function _resolveACLProxyAddress(_log: (...args: unknown[]) => void): Promise<string> {
    if (isFreshLocalNetwork()) {
        _log("Local network detected, deploying contracts first...");
        const { acl } = await deploy(false);
        return acl.address;
    }

    return await readDeployedAddress("ACL#proxy");
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    await upgradeACL();
}

function _isHardhatRunCommand() {
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/upgrade-acl.ts");
}
