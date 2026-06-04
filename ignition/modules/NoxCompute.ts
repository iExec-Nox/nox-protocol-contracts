import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module to deploy NoxCompute proxy and implementation contracts.
 */
export default buildModule("NoxCompute", (m) => {
    const initialAdmin = m.getParameter("initialAdmin");
    const initialUpgrader = m.getParameter("initialUpgrader");
    const kmsPublicKey = m.getParameter("kmsPublicKey");
    const gateway = m.getParameter("gateway");
    const implementation = m.contract("NoxCompute", [], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [
        initialAdmin,
        initialUpgrader,
        kmsPublicKey,
        gateway,
    ]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
