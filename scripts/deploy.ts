import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";
import NoxCompute from "../ignition/modules/NoxCompute.ts";
import config from "../config/config.ts";
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
    const chainConfig = config[connection.networkName];
    if (!chainConfig) {
        throw new Error(`No chain config found for network: ${connection.networkName}`);
    }

    _log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Chain config:`, chainConfig);
    // All deploy parameters come from chain config (single source of truth).
    const { initialAdmin, initialUpgrader, kmsPublicKey } = chainConfig;
    if (!initialAdmin || !initialUpgrader) {
        throw new Error(
            `Role addresses missing in chainConfig for network "${connection.networkName}": ` +
                "initialAdmin and initialUpgrader are required.",
        );
    }
    if (!kmsPublicKey) {
        throw new Error(`kmsPublicKey missing in chainConfig for network "${connection.networkName}".`);
    }
    const { proxy: noxComputeProxy } = await connection.ignition.deploy(NoxCompute, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        strategy: "create2",
        parameters: {
            NoxCompute: {
                initialAdmin,
                initialUpgrader,
                kmsPublicKey,
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
