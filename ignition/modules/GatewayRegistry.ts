import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("GatewayRegistry", (m) => {
    const initialAdmin = m.getParameter("initialAdmin");
    const initialUpgrader = m.getParameter("initialUpgrader");

    const implementation = m.contract("GatewayRegistry", [], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [initialAdmin, initialUpgrader]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
