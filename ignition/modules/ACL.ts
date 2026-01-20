import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ACL", (m) => {
    const initialOwner = m.getParameter("initialOwner");
    const teeComputeManager = m.getParameter("teeComputeManager");

    const implementation = m.contract("ACL", [], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [initialOwner, teeComputeManager]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
