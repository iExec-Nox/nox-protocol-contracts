import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

// TODO deploy proxy
export default buildModule("GatewayRegistryModule", (m) => {
    const gatewayRegistry = m.contract("GatewayRegistry");
    return { gatewayRegistry };
});
