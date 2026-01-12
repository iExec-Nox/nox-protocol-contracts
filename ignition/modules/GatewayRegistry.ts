import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("GatewayRegistryModule", (m) => {
    const gatewayRegistry = m.contract("GatewayRegistry");
    return { gatewayRegistry };
});
