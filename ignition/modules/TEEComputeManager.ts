import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module to deploy TEEComputeManager proxy and implementation contracts.
 */
export default buildModule("TEEComputeManager", (m) => {
    const initialOwner = m.getParameter("initialOwner");
    const implementation = m.contract("TEEComputeManager", [], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [initialOwner]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
