import path from "path";
import ACL from "../ignition/modules/ACL.js";
import TEEComputeManager from "../ignition/modules/TEEComputeManager.js";
import config from "../config/config.js";
import connection from "./utils/hardhat-connection-singleton.js";

// Deployment script for the Nox Contracts. It fetches the target chain config
// from the config file and uses the Hardhat Ignition plugin to import and deploy
// the modules defined in the `ignition/modules` folder.
// Usage: `hardhat run scripts/deploy.ts --network <network-name>`

/**
 * Deployment function to be imported in other scripts.
 * @param log whether to print deployment messages or not, useful to get clean test logs
 * @returns Viem contract instances for the deployed proxy contracts
 */
export async function deploy(log = true) {
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const chainConfig = config[connection.networkName];
    if (!chainConfig) {
        throw new Error(`No chain config found for network: ${connection.networkName}`);
    }
    if (log) {
        console.log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
        console.log(`Chain config:`, chainConfig);
    }
    // Deploy TEEComputeManager.
    const { proxy: teeComputeManagerProxy } = await connection.ignition.deploy(TEEComputeManager, {
        deploymentId: connection.networkName,
        displayUi: log,
        parameters: {
            TEEComputeManager: {
                initialOwner: chainConfig.initialAdmin,
            },
        },
    });
    if (log) {
        console.log(`TEEComputeManager: ${teeComputeManagerProxy.address}`);
    }
    // Deploy ACL
    const { proxy: aclProxy } = await connection.ignition.deploy(ACL, {
        deploymentId: connection.networkName,
        displayUi: log,
        parameters: {
            ACL: {
                initialOwner: chainConfig.initialAdmin,
                teeComputeManager: teeComputeManagerProxy.address,
            },
        },
    });
    if (log) {
        console.log(`ACL: ${aclProxy.address}`);
    }
    // Update ACL address in TEEComputeManager.
    const teeComputeManager = await viem.getContractAt("ITEEComputeManager", teeComputeManagerProxy.address);
    const setAclTxHash = await teeComputeManager.write.setAcl([aclProxy.address]);
    await publicClient.waitForTransactionReceipt({ hash: setAclTxHash });

    // Get contract instances as Viem contracts.
    const aclContract = await viem.getContractAt("ACL", aclProxy.address);
    return {
        acl: aclContract,
        teeComputeManager,
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
