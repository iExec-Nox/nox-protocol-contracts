import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ACLModule", (m) => {
  const acl = m.contract("ACL");

  return { acl };
});
