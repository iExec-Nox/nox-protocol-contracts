import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";
import { deploy } from "./deploy.ts";
import { isFreshLocalNetwork } from "./utils/network.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";
import connection from "./utils/hardhat-connection-singleton.ts";
import { Address } from "viem";

// Script to upgrade the NoxCompute proxy to a new implementation.
// Uses @openzeppelin/hardhat-upgrades for upgrade safety checks
// (storage layout validation, implementation compatibility).
//
// The proxy is deployed via Ignition (CREATE2), so we use forceImport to register it
// with the OpenZeppelin Upgrades manifest before the first upgrade.
//
// When running on a local (edr-simulated) network, a fresh deployment is performed first
// since each `hardhat run` starts a clean chain.
//
// Usage: `hardhat run scripts/upgrade.ts --network <network-name>`

/**
 * Upgrades the NoxCompute proxy to a new implementation.
 * @param proxyAddress the NoxCompute proxy address to upgrade, resolved automatically if not provided
 * @param printLogs whether to print logs or not
 * @param contractName the contract to deploy as new implementation (defaults to "NoxCompute")
 * @returns The new implementation address
 */
export async function upgradeNoxCompute(proxyAddress?: Address, printLogs = true, contractName = "NoxCompute") {
    const _log = printLogs ? console.log : () => {};
    const { ethers } = connection;

    _log(`Upgrading NoxCompute proxy`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    const noxComputeProxyAddress: Address = await _resolveProxyAddress(proxyAddress, _log);
    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);

    const api = await upgrades(hre, connection);
    const NoxComputeFactory = await ethers.getContractFactory("NoxCompute");
    const NewImplFactory = await ethers.getContractFactory(contractName);

    // Register the Ignition-deployed proxy with the OZ manifest (idempotent).
    // This is required because the proxy was deployed via Ignition, not via the OZ plugin.
    await api.forceImport(noxComputeProxyAddress, NoxComputeFactory, {
        kind: "uups",
    });

    // Upgrade the proxy using the OpenZeppelin Upgrades plugin.
    // This handles: storage layout validation, new implementation deployment,
    // and calling upgradeToAndCall on the UUPS proxy.
    await api.upgradeProxy(noxComputeProxyAddress, NewImplFactory, {
        unsafeAllow: ["constructor"],
    });
    const implAddress = await api.erc1967.getImplementationAddress(noxComputeProxyAddress);
    _log(`New implementation deployed at: ${implAddress}`);
    _log("NoxCompute proxy upgraded successfully");

    return implAddress as Address;
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

    const resolved = await readDeployedAddress("NoxCompute#proxy");
    return resolved as Address;
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    await upgradeNoxCompute();
}

function _isHardhatRunCommand() {
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/upgrade.ts");
}
