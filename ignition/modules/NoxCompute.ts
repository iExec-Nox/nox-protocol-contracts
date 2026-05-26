import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module to deploy NoxCompute proxy and implementation contracts.
 *
 * `initialize` only seeds the base state (KMS key, proof expiration, zero handle seeds).
 * Role setup happens in a follow-up `initializeV3(admin, upgrader, paymentManager)` call,
 * triggered by the deploy script — keeping module parameters minimal here.
 */
export default buildModule("NoxCompute", (m) => {
    const kmsPublicKey = m.getParameter("kmsPublicKey");
    const cuPerOperation = m.getParameter("cuPerOperation", 1);
    const implementation = m.contract("NoxCompute", [cuPerOperation], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [kmsPublicKey]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
