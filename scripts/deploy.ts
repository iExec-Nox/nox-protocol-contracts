import ACL from "../ignition/modules/ACL.js";
import TEEComputeManager from "../ignition/modules/TEEComputeManager.js";
import config from "../config/config.js";
import connection from "./utils/hardhat-connection-singleton.js";

// Deployment script for the Nox Contracts.
// On real networks: Uses deterministic CREATE2 deployment via CreateX factory.
// On local/test networks: Uses regular deployment (CreateX not available).
//
// The CREATE2 salt is configured in hardhat.config.ts under ignition.strategyConfig.create2.salt
//
// Usage: `hardhat run scripts/deploy.ts --network <network-name>`

// Networks where CreateX factory is not deployed (local/test networks)
const NON_CREATE2_NETWORKS = ["hardhat", "default", "localhost"];

/**
 * Deployment function to be imported in other scripts.
 * @param printLogs whether to print deployment messages or not, useful to get clean test logs
 * @returns Viem contract instances for the deployed proxy contracts
 */
export async function deploy(printLogs = true) {
    const _log = printLogs ? console.log : () => {};
    const { viem } = connection;
    const publicClient = await viem.getPublicClient();
    const chainConfig = config[connection.networkName];
    if (!chainConfig) {
        throw new Error(`No chain config found for network: ${connection.networkName}`);
    }

    // Determine deployment strategy based on network
    const useCreate2 = !NON_CREATE2_NETWORKS.includes(connection.networkName);
    const strategy = useCreate2 ? "create2" : "basic";

    _log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Strategy: ${strategy}`);
    _log(`Chain config:`, chainConfig);
    // Deploy ACL proxy (initialized with owner).
    const { proxy: aclProxy } = await connection.ignition.deploy(ACL, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        ...(useCreate2 && { strategy: "create2" }),
        parameters: {
            ACL: {
                initialOwner: chainConfig.initialOwner,
            },
        },
    });
    _log(`ACL: ${aclProxy.address}`);
    // Deploy TEEComputeManager with ACL address as constructor arg.
    const { proxy: teeComputeManagerProxy } = await connection.ignition.deploy(TEEComputeManager, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        ...(useCreate2 && { strategy: "create2" }),
        parameters: {
            TEEComputeManager: {
                initialOwner: chainConfig.initialOwner,
                acl: aclProxy.address,
            },
        },
    });
    _log(`TEEComputeManager: ${teeComputeManagerProxy.address}`);
    // Set TEEComputeManager address in ACL.
    const acl = await viem.getContractAt("ACL", aclProxy.address);
    const setTxHash = await acl.write.setTeeComputeManager([teeComputeManagerProxy.address]);
    await publicClient.waitForTransactionReceipt({ hash: setTxHash });

    // Get TEEComputeManager contract instance.
    const teeComputeManager = await viem.getContractAt("TEEComputeManager", teeComputeManagerProxy.address);
    return {
        acl,
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
