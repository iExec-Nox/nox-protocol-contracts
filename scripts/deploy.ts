import path from "path";
import GatewayRegistry from "../ignition/modules/GatewayRegistry.js";
import ACL from "../ignition/modules/ACL.js";
import config from "../config/config.js";
import connection from "./utils/ConnectionSingleton.js";

// Deployment script for the Nox Contracts. It fetches the target chain config
// from the config file and uses the Hardhat Ignition plugin to import and deploy
// the modules defined in the `ignition/modules` folder.
// Usage: `hardhat run scripts/deploy.ts --network <network-name>`

/**
 * Deployment function to be imported in other scripts.
 * @param log whether to logs deployment messages or not
 * @returns addresses of deployed proxy contracts
 */
export async function deploy(log = true) {
    const chainConfig = config[connection.networkName];
    if (log) {
        console.log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
        console.log(`Chain config:`, chainConfig);
    }
    // Deploy GatewayRegistry
    const { proxy: gatewayRegistryProxy } = await connection.ignition.deploy(GatewayRegistry, {
        deploymentId: connection.networkName,
        displayUi: log,
        parameters: {
            GatewayRegistry: {
                initialAdmin: chainConfig.initialAdmin,
                initialUpgrader: chainConfig.initialUpgrader,
            },
        },
    });
    if (log) {
        console.log(`GatewayRegistry: ${gatewayRegistryProxy.address}`);
    }
    // TODO Deploy TEE Compute Manager
    const teeComputeManager = "0x000000000000000000000000000000000000000a";
    // Deploy ACL
    const { acl } = await connection.ignition.deploy(ACL, {
        deploymentId: connection.networkName,
        displayUi: log,
        parameters: {
            ACL: {
                teeComputeManager: teeComputeManager,
            },
        },
    });
    if (log) {
        console.log(`ACL: ${acl.address}`);
    }
    // Get contract instances as Viem contracts.
    const { viem } = connection;
    const gatewayRegistry = await viem.getContractAt("GatewayRegistry", gatewayRegistryProxy.address);
    const aclContract = await viem.getContractAt("ACL", acl.address);
    return {
        gatewayRegistry,
        acl: aclContract,
    };
}

// Execute the deployment only if the script is run directly.
// This disables execution when the file is imported as a module.
if (_isHardhatRunCommand()) {
    await deploy();
}

function _isHardhatRunCommand() {
    const filename = path.basename(import.meta.filename);
    // When running `hardhat run scripts/deploy.ts`, the argv looks like:
    // [ "/.../bin/node", "/.../cli.js", "run", "scripts/deploy.ts"];
    return process.argv[2] === "run" && process.argv[3].includes(filename);
}
