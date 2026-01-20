import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ACL", (m) => {
    const initialAdmin = m.getParameter("initialAdmin");
    const initialUpgrader = m.getParameter("initialUpgrader");
    const teeComputeManager = m.getParameter("teeComputeManager");

    const implementation = m.contract("ACL", [], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [
        initialAdmin,
        initialUpgrader,
        teeComputeManager,
    ]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
