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
    // KMS_PUBLIC_KEY env var takes precedence, then falls back to the config value.
    const kmsPublicKey = process.env.KMS_PUBLIC_KEY ?? chainConfig.kmsPublicKey;
    if (!kmsPublicKey) {
        throw new Error("KMS_PUBLIC_KEY environment variable is required");
    }
    // Role accounts. Each env var takes precedence, then falls back to `initialOwner` from
    // the chain config. This keeps single-signer setups simple while allowing per-role
    // overrides in CI/CD or for production deployments.
    const fallbackAdmin = chainConfig.initialOwner;
    const initialAdmin = process.env.INITIAL_ADMIN ?? fallbackAdmin;
    const initialUpgrader = process.env.INITIAL_UPGRADER ?? fallbackAdmin;
    const initialPaymentManager = process.env.INITIAL_PAYMENT_MANAGER ?? fallbackAdmin;
    if (!initialAdmin || !initialUpgrader || !initialPaymentManager) {
        throw new Error(
            "INITIAL_ADMIN / INITIAL_UPGRADER / INITIAL_PAYMENT_MANAGER (or chainConfig.initialOwner) are required",
        );
    }

    const { proxy: noxComputeProxy } = await connection.ignition.deploy(NoxCompute, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        strategy: "create2",
        parameters: {
            NoxCompute: {
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

    // Set up AccessControl roles via initializeV3 (reinitializer v3). This separates
    // base state setup from role configuration so the same NoxCompute implementation
    // can be used for fresh deploys and for upgrades from older Ownable-based proxies.
    _log(`Initializing roles via initializeV3...`);
    _log(`  admin:          ${initialAdmin}`);
    _log(`  upgrader:       ${initialUpgrader}`);
    _log(`  paymentManager: ${initialPaymentManager}`);
    const tx = await noxCompute.write.initializeV3([
        initialAdmin as `0x${string}`,
        initialUpgrader as `0x${string}`,
        initialPaymentManager as `0x${string}`,
    ]);
    _log(`initializeV3 tx: ${tx}`);

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
