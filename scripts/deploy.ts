import ACL from "../ignition/modules/ACL.ts";
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
    const publicClient = await viem.getPublicClient();
    const chainConfig = config[connection.networkName];
    if (!chainConfig) {
        throw new Error(`No chain config found for network: ${connection.networkName}`);
    }

    _log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Chain config:`, chainConfig);
    // Deploy ACL proxy (initialized with owner).
    const { proxy: aclProxy } = await connection.ignition.deploy(ACL, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        strategy: "create2",
        parameters: {
            ACL: {
                initialOwner: chainConfig.initialOwner,
            },
        },
    });
    _log(`ACL: ${aclProxy.address}`);
    // Deploy NoxCompute with ACL address as constructor arg.
    // KMS_PUBLIC_KEY env var takes precedence, then falls back to the config value.
    const kmsPublicKey = process.env.KMS_PUBLIC_KEY ?? chainConfig.kmsPublicKey;
    if (!kmsPublicKey) {
        throw new Error("KMS_PUBLIC_KEY environment variable is required");
    }
    const { proxy: noxComputeProxy } = await connection.ignition.deploy(NoxCompute, {
        deploymentId: connection.networkName,
        displayUi: printLogs,
        strategy: "create2",
        parameters: {
            NoxCompute: {
                initialOwner: chainConfig.initialOwner,
                acl: aclProxy.address,
                kmsPublicKey,
            },
        },
    });
    _log(`NoxCompute: ${noxComputeProxy.address}`);
    // Set NoxCompute address in ACL.
    const acl = await viem.getContractAt("ACL", aclProxy.address);
    const setTxHash = await acl.write.setNoxCompute([noxComputeProxy.address]);
    await publicClient.waitForTransactionReceipt({ hash: setTxHash });

    // Get NoxCompute contract instance.
    const noxCompute = await viem.getContractAt("NoxCompute", noxComputeProxy.address);
    return {
        acl,
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
