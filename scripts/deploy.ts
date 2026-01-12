import hre from "hardhat";
import GatewayRegistry from "../ignition/modules/GatewayRegistry.js";
import ACL from "../ignition/modules/ACL.js";
import config from "../config/config.js";

async function main() {
    const connection = await hre.network.connect();
    const chainConfig = config[connection.networkName];
    console.log(`Deploying to network: ${connection.networkName} (chainId: ${chainConfig.chainId})`);
    console.log(`Chain config:`, chainConfig);

    const { proxy: gatewayRegistryProxy } = await connection.ignition.deploy(GatewayRegistry, {
        deploymentId: connection.networkName,
        displayUi: true,
        parameters: {
            GatewayRegistry: {
                initialAdmin: chainConfig.initialAdmin,
                initialUpgrader: chainConfig.initialUpgrader,
            },
        },
    });
    console.log(`GatewayRegistry: ${gatewayRegistryProxy.address}`);
}

main().catch(console.error);
