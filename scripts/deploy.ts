import hre from "hardhat";
import GatewayRegistry from "../ignition/modules/GatewayRegistry.js";
import ACL from "../ignition/modules/ACL.js";
import config from "../config/config.js";
import connection from "./ConnectionSingleton.js";

export async function deploy() {
    const chainConfig = config[connection.networkName];
    console.log(`Deploying to network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    console.log(`Chain config:`, chainConfig);
    // Deploy GatewayRegistry
    const { proxy: gatewayRegistryProxy } = await connection.ignition.deploy(GatewayRegistry, {
        deploymentId: connection.networkName,
        displayUi: false,
        parameters: {
            GatewayRegistry: {
                initialAdmin: chainConfig.initialAdmin,
                initialUpgrader: chainConfig.initialUpgrader,
            },
        },
    });
    console.log(`GatewayRegistry: ${gatewayRegistryProxy.address}`);
    // TODO Deploy TEE Compute Manager
    const teeComputeManager = "0x000000000000000000000000000000000000000a";
    // Deploy ACL
    const { acl } = await connection.ignition.deploy(ACL, {
        deploymentId: connection.networkName,
        displayUi: false,
        parameters: {
            ACL: {
                teeComputeManager: teeComputeManager,
            },
        },
    });
    console.log(`ACL: ${acl.address}`);
    // Get contract instances as Viem contracts.
    const { viem } = connection;
    const gatewayRegistry = await viem.getContractAt("GatewayRegistry", gatewayRegistryProxy.address);
    const aclContract = await viem.getContractAt("ACL", acl.address);
    return {
        gatewayRegistry,
        acl: aclContract,
    };
}

await deploy();
