import * as core from "@actions/core";
import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";
import { Address, Hex } from "viem";
import { deploy } from "./deploy.ts";
import connection from "./utils/hardhat-connection-singleton.ts";
import { isFreshLocalNetwork } from "./utils/network.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";

// Script to upgrade the NoxCompute proxy to a new implementation.
// Uses @openzeppelin/hardhat-upgrades for upgrade safety checks
// (storage layout validation, implementation compatibility).
//
// Two flows depending on who holds the UPGRADER_ROLE:
//   - Direct upgrade (testnets): `upgradeNoxCompute` executes the upgrade with the upgrader EOA.
//   - Prepare-only (mainnet, Safe multisig): `prepareUpgradeNoxCompute` deploys the new
//     implementation and returns the `upgradeToAndCall` calldata to propose to the Safe.
//
// When running on a local (edr-simulated) network, a fresh deployment is performed first
// since each `hardhat run` starts a clean chain.
//
// Usage:
//   - Execute:  `hardhat run scripts/upgrade.ts --network <network-name>`
//   - Prepare:  `UPGRADE_ACTION=prepare hardhat run scripts/upgrade.ts --network <network-name>`

/**
 * Upgrades the NoxCompute proxy to a new implementation.
 * Should be updated and adapted for each upgrade.
 * @param proxyAddress the NoxCompute proxy address to upgrade, resolved automatically if not provided
 * @param printLogs whether to print logs or not
 * @param contractName the contract to deploy as new implementation (defaults to "NoxCompute")
 * @returns The new implementation address
 */
export async function upgradeNoxCompute(proxyAddress?: Address, printLogs = true, contractName = "NoxCompute") {
    const _log = printLogs ? console.log : () => {};
    const { ethers } = connection;
    const [upgrader] = await ethers.getSigners();

    _log(`Upgrading NoxCompute proxy`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Upgrader address: ${upgrader?.address}`);

    const noxComputeProxyAddress: Address = await _resolveProxyAddress(proxyAddress, _log);
    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);

    const api = await upgrades(hre, connection);
    const newImplFactory = await ethers.getContractFactory(contractName);

    // Upgrade the proxy using the OpenZeppelin Upgrades plugin.
    // The proxy must already be registered in the OZ manifest (done in deploy.ts via forceImport).
    const upgrade = await api.upgradeProxy(noxComputeProxyAddress, newImplFactory, {
        unsafeAllow: ["constructor"],
        // call: { fn: "initializeV4", args: [] },
    });
    await upgrade.waitForDeployment();

    _log("Upgrade transaction:", upgrade.deploymentTransaction()?.hash);
    const newImplementation = await api.erc1967.getImplementationAddress(noxComputeProxyAddress);
    _log(`New implementation deployed at: ${newImplementation}`);
    _log("NoxCompute proxy upgraded successfully");

    return newImplementation as Address;
}

/**
 * Prepares a NoxCompute proxy upgrade for a Safe multisig proposal.
 * Deploys the new implementation and builds the `upgradeToAndCall` calldata without executing it.
 * Should be updated and adapted for each upgrade.
 * @param proxyAddress the NoxCompute proxy address to upgrade, resolved automatically if not provided
 * @param printLogs whether to print logs or not
 * @param contractName the contract to deploy as new implementation (defaults to "NoxCompute")
 * @returns The proxy address, the new implementation address and the `upgradeToAndCall` calldata
 */
export async function prepareUpgradeNoxCompute(proxyAddress?: Address, printLogs = true, contractName = "NoxCompute") {
    const _log = printLogs ? console.log : () => {};
    const { ethers } = connection;
    const [proposer] = await ethers.getSigners();

    _log(`Preparing NoxCompute upgrade (Safe multisig proposal)`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Proposer/deployer address: ${proposer?.address}`);

    const noxComputeProxyAddress: Address = await _resolveProxyAddress(proxyAddress, _log);
    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);

    const api = await upgrades(hre, connection);
    const newImplFactory = await ethers.getContractFactory(contractName);

    const newImplementation = (await api.prepareUpgrade(noxComputeProxyAddress, newImplFactory, {
        unsafeAllow: ["constructor"],
    })) as Address;
    _log(`New implementation deployed at: ${newImplementation}`);

    // Encode the UUPS upgrade calldata: `upgradeToAndCall(newImplementation, data)`.
    // `data` is empty unless a reinitializer must run atomically as part of the upgrade.
    const upgradeData = "0x";
    const proxy = await ethers.getContractAt(contractName, noxComputeProxyAddress);
    const calldata = proxy.interface.encodeFunctionData("upgradeToAndCall", [newImplementation, upgradeData]) as Hex;
    _log(`Upgrade calldata (upgradeToAndCall): ${calldata}`);
    _log("Submit this transaction to the Safe multisig: { to: proxy, value: 0, data: calldata }");

    return { proxyAddress: noxComputeProxyAddress, newImplementation, calldata };
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

    const noxComputeProxyAddress = await readDeployedAddress("NoxCompute#proxy");
    return noxComputeProxyAddress as Address;
}

// Execute the script only if run directly.
if (_isHardhatRunCommand()) {
    if (process.env.UPGRADE_ACTION === "prepare") {
        const { proxyAddress, newImplementation, calldata } = await prepareUpgradeNoxCompute();

        if (process.env.GITHUB_OUTPUT) {
            core.setOutput("transaction-to", proxyAddress);
            core.setOutput("transaction-data", calldata);
            core.setOutput("new-implementation", newImplementation);
        }
    } else {
        await upgradeNoxCompute();
    }
}

function _isHardhatRunCommand() {
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/upgrade.ts");
}
