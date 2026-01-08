import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ACLModule", (m) => {
    const teeComputeManager = m.getParameter("teeComputeManager");
    const acl = m.contract("ACL", [teeComputeManager]);

    return { acl };
});
