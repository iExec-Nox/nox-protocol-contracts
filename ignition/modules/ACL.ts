import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ACL", (m) => {
    const teeComputeManager = m.getParameter("teeComputeManager");
    const acl = m.contract("ACL", [teeComputeManager]);
    return { acl };
});
