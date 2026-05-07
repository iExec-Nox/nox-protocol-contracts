import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module to upgrade NoxCompute proxy to a new implementation contract.
 */
export default buildModule("NoxComputeUpgrade", (m) => {
    const proxyAddress = m.getParameter("proxyAddress");
    const proxy = m.contractAt("NoxCompute", proxyAddress, { id: "proxy" });
    const newImplementation = m.contract("NoxCompute", [], { id: "implementation" });
    const calldata = m.encodeFunctionCall(newImplementation, "initializeV2", []);
    m.call(proxy, "upgradeToAndCall", [newImplementation, calldata], { id: "upgradeCall" });
    return { implementation: newImplementation, proxy };
});
