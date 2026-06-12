import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";

import { getChainConfig } from "../config/config.ts";
import NoxCompute from "../ignition/modules/NoxCompute.ts";
import connection from "./utils/hardhat-connection-singleton.ts";

// Deployment script for the Nox Contracts.
// Uses deterministic CREATE2 deployment via CreateX factory.
// On local networks (chainId 31337), Ignition automatically deploys CreateX if not present.
//
// Usage: `hardhat run scripts/deploy.ts --network <network-name>`

/**
 * Deployment function to be imported in other scripts.
 * @param printLogs whether to print deployment messages or not, useful to get clean test logs
 * @returns Viem contract instances for the deployed proxy contracts
 */
export async function deploy(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const chainConfig = getChainConfig(connection.networkName);
    const [deployerClient] = await viem.getWalletClients();

    _log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Deployer address: ${deployerClient?.account.address}`);
    _log(`Chain config:`, chainConfig);
    const { initialAdmin, initialUpgrader, kmsPublicKey, gateway } = chainConfig;
    const { proxy: noxComputeProxy } = await connection.ignition.deploy(NoxCompute, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        strategy: "create2",
        parameters: {
            NoxCompute: {
                initialAdmin,
                initialUpgrader,
                kmsPublicKey,
                gateway,
            },
        },
    });
    _log(`NoxCompute: ${noxComputeProxy.address}`);

    // Register the Ignition-deployed proxy with the OZ Upgrades manifest (idempotent).
    // This is required because the proxy was deployed via Ignition, not via the OZ plugin.
    // Doing it here (right after deploy) ensures the manifest references the correct implementation.
    const api = await upgrades(hre, connection);
    const noxComputeFactory = await connection.ethers.getContractFactory("NoxCompute");
    await api.forceImport(noxComputeProxy.address, noxComputeFactory, { kind: "uups" });

    // Get NoxCompute contract instance.
    const noxCompute = await viem.getContractAt("NoxCompute", noxComputeProxy.address);
    return {
        noxCompute,
    };
}

// Execute the deployment only if the script is run directly.
// This disables execution when the file is imported as a module.
if (_isHardhatRunCommand()) {
    await deploy();
}

function _isHardhatRunCommand() {
    // When running `hardhat run scripts/deploy.ts`, the argv looks like:
    // [ "/.../bin/node", "/.../cli.js", "run", "scripts/deploy.ts"];
    return process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/deploy.ts");
}
