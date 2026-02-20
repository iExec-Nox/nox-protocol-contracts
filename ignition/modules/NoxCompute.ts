import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module to deploy NoxCompute proxy and implementation contracts.
 */
export default buildModule("NoxCompute", (m) => {
    const initialOwner = m.getParameter("initialOwner");
    const kmsPublicKey = m.getParameter("kmsPublicKey");
    const implementation = m.contract("NoxCompute", [], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [initialOwner, kmsPublicKey]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
