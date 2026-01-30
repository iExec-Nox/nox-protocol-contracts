import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ACL", (m) => {
    const implementation = m.contract("ACL", [], {
        id: "implementation",
    });
    const proxy = m.contract("ERC1967Proxy", [implementation, "0x"], {
        id: "proxy",
    });
    return { implementation, proxy };
});
