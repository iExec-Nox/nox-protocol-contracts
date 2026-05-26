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
    // Deploy NoxCompute.
    // TODO read env variables in config.ts and validate config them there and use config.get().
    // KMS_PUBLIC_KEY env var takes precedence, then falls back to the config value.
    const kmsPublicKey = process.env.KMS_PUBLIC_KEY ?? chainConfig.kmsPublicKey;
    if (!kmsPublicKey) {
        throw new Error("KMS_PUBLIC_KEY environment variable is required");
    }
    // Role accounts. Resolution order per role: env var → chain-config field
    // (`initialAdmin`/`initialUpgrader`/`initialPaymentManager`) → `initialOwner` fallback.
    const initialAdmin = process.env.INITIAL_ADMIN ?? chainConfig.initialAdmin ?? chainConfig.initialOwner;
    const initialUpgrader = process.env.INITIAL_UPGRADER ?? chainConfig.initialUpgrader ?? chainConfig.initialOwner;
    const initialPaymentManager =
        process.env.INITIAL_PAYMENT_MANAGER ?? chainConfig.initialPaymentManager ?? chainConfig.initialOwner;
    if (!initialAdmin || !initialUpgrader || !initialPaymentManager) {
        throw new Error(
            "Role addresses are required: set INITIAL_ADMIN / INITIAL_UPGRADER / INITIAL_PAYMENT_MANAGER, " +
                "or chainConfig.initialAdmin / initialUpgrader / initialPaymentManager, or chainConfig.initialOwner.",
        );
    }
    // CU_PER_OPERATION env var takes precedence, then falls back to the config value.
    const cuPerOperation =
        process.env.CU_PER_OPERATION !== undefined ? Number(process.env.CU_PER_OPERATION) : chainConfig.cuPerOperation;
    const { proxy: noxComputeProxy } = await connection.ignition.deploy(NoxCompute, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        strategy: "create2",
        parameters: {
            NoxCompute: {
                kmsPublicKey,
                cuPerOperation,
            },
        },
    });
    _log(`NoxCompute: ${noxComputeProxy.address}`);

    // Register the Ignition-deployed proxy with the OZ Upgrades manifest (idempotent).
    // This is required because the proxy was deployed via Ignition, not via the OZ plugin.
    // Doing it here (right after deploy) ensures the manifest references the correct implementation.
    const api = await upgrades(hre, connection);
    const noxComputeFactory = await connection.ethers.getContractFactory("NoxCompute");
    await api.forceImport(noxComputeProxy.address, noxComputeFactory, {
        kind: "uups",
        constructorArgs: [cuPerOperation],
    });

    // Get NoxCompute contract instance.
    const noxCompute = await viem.getContractAt("NoxCompute", noxComputeProxy.address);

    // Run the same reinitializer sequence a long-lived proxy would have gone through
    // (initialize → initializeV2 → initializeV3).
    _log(`Running initializeV2...`);
    const txV2 = await noxCompute.write.initializeV2();
    _log(`initializeV2 succeeded, tx: ${txV2}`);

    _log(`Running initializeV3...`);
    _log(`  admin:          ${initialAdmin}`);
    _log(`  upgrader:       ${initialUpgrader}`);
    _log(`  paymentManager: ${initialPaymentManager}`);
    const txV3 = await noxCompute.write.initializeV3([
        initialAdmin as `0x${string}`,
        initialUpgrader as `0x${string}`,
        initialPaymentManager as `0x${string}`,
    ]);
    _log(`initializeV3 succeeded, tx: ${txV3}`);

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
