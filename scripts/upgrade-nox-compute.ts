import { deploy } from "./deploy.ts";
import { isFreshLocalNetwork } from "./utils/network.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";
import connection from "./utils/hardhat-connection-singleton.ts";
import { Address } from "viem";

// Script to upgrade the NoxCompute proxy to a new implementation.
// It reads the deployed proxy from ignition deployment artifacts,
// deploys the new implementation, and calls upgradeToAndCall on the proxy.
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
 * @param printLogs whether to print logs or not
 * @returns The new implementation address
 */
export async function upgradeNoxCompute(proxyAddress?: Address, printLogs = true) {
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

    const noxComputeProxyAddress: Address = await _resolveProxyAddress(proxyAddress, _log);
    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);

    // Deploy new implementation
    const newImplementation = await viem.deployContract(contractName, [], {
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

/**
 * Resolves the NoxCompute proxy address.
 * Uses provided address if available, otherwise:
 * On local non-forked (edr-simulated) networks, deploys contracts first since each
 * `hardhat run` starts a fresh chain with no prior state.
 * On remote or forked networks, reads from ignition deployment artifacts.
 */
async function _resolveProxyAddress(
    proxyAddress: Address | undefined,
    _log: (...args: unknown[]) => void,
): Promise<Address> {
    if (proxyAddress) {
        return proxyAddress;
    }

    if (isFreshLocalNetwork()) {
        _log("Local network detected, deploying contracts first...");
        const { noxCompute } = await deploy(false);
        return noxCompute.address;
    }

    const noxComputeProxyAddress = proxyAddress ?? (await readDeployedAddress("NoxCompute#proxy"));
    return noxComputeProxyAddress as Address;
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
