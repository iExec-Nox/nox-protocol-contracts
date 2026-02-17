import { parseEther } from "viem";
import { deploy } from "./deploy.ts";
import { isFreshLocalNetwork } from "./utils/network.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";
import config from "../config/config.ts";
import connection from "./utils/hardhat-connection-singleton.ts";

// Script to upgrade the NoxCompute proxy to a new implementation.
// It reads the deployed proxy and ACL addresses from ignition deployment artifacts,
// deploys the new implementation (with ACL as constructor arg), and calls upgradeToAndCall on the proxy.
//
// When running on a local (edr-simulated) network, a fresh deployment is performed first
// since each `hardhat run` starts a clean chain.
//
// Usage: `hardhat run scripts/upgrade-nox-compute.ts --network <network-name>`

// TODO: Use @openzeppelin/hardhat-upgrades plugin for upgrade safety checks
// (storage layout validation, implementation compatibility) when it becomes compatible with Hardhat 3.

/**
 * Upgrades the NoxCompute proxy to a new implementation.
 * @param proxyAddress the NoxCompute proxy address to upgrade, resolved automatically if not provided
 * @param aclAddress the ACL proxy address (constructor arg), resolved automatically if not provided
 * @param printLogs whether to print logs or not
 * @returns The new implementation address
 */
export async function upgradeNoxCompute(proxyAddress?: string, aclAddress?: string, printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const walletClients = await viem.getWalletClients();

    const isLocalNetwork = connection.networkConfig.type === "edr-simulated";
    const chainConfig = config[connection.networkName];
    const owner = chainConfig.initialOwner as `0x${string}`;

    if (!isLocalNetwork) {
        const ownerClient = walletClients[0];
        if (!ownerClient) {
            throw new Error("No owner wallet available. Set PRIVATE_KEY environment variable.");
        }
    }

    // TODO: Replace with the actual new NoxCompute contract name
    const contractName = "NoxComputeV2Mock";

    _log(`Upgrading NoxCompute proxy`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Using owner address: ${owner}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    const { noxComputeProxyAddress, aclProxyAddress } = await _resolveProxyAddresses(proxyAddress, aclAddress, _log);
    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);
    _log(`ACL proxy address: ${aclProxyAddress}`);

    // On local EDR networks, impersonate the owner account
    if (isLocalNetwork) {
        await connection.networkHelpers.impersonateAccount(owner);
        await connection.networkHelpers.setBalance(owner, parseEther("1000"));
    }

    // Deploy new implementation with ACL address as constructor arg
    const newImplementation = await viem.deployContract(contractName, [aclProxyAddress]);
    _log(`New implementation deployed at: ${newImplementation.address}`);

    // Upgrade the proxy via UUPS upgradeToAndCall
    const proxy = await viem.getContractAt(contractName, noxComputeProxyAddress);
    const txHash = await proxy.write.upgradeToAndCall(
        [newImplementation.address, "0x"],
        isLocalNetwork ? { account: owner } : undefined,
    );
    _log(`Upgrade transaction hash: ${txHash}`);

    await publicClient.waitForTransactionReceipt({ hash: txHash });
    _log("NoxCompute proxy upgraded successfully");

    return newImplementation.address;
}

/**
 * Resolves the NoxCompute and ACL proxy addresses.
 * Uses provided addresses if available, otherwise:
 * On local non-forked (edr-simulated) networks, deploys contracts first since each
 * `hardhat run` starts a fresh chain with no prior state.
 * On remote or forked networks, reads from ignition deployment artifacts.
 */
async function _resolveProxyAddresses(
    proxyAddress: string | undefined,
    aclAddress: string | undefined,
    _log: (...args: unknown[]) => void,
): Promise<{ noxComputeProxyAddress: string; aclProxyAddress: string }> {
    if (proxyAddress && aclAddress) {
        return { noxComputeProxyAddress: proxyAddress, aclProxyAddress: aclAddress };
    }

    if (isFreshLocalNetwork()) {
        _log("Local network detected, deploying contracts first...");
        const { acl, noxCompute } = await deploy(false);
        return { noxComputeProxyAddress: noxCompute.address, aclProxyAddress: acl.address };
    }

    const noxComputeProxyAddress = proxyAddress ?? (await readDeployedAddress("NoxCompute#proxy"));
    const aclProxyAddress = aclAddress ?? (await readDeployedAddress("ACL#proxy"));
    return { noxComputeProxyAddress, aclProxyAddress };
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
