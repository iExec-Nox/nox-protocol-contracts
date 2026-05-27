import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Hardhat Ignition module to deploy NoxCompute proxy and implementation contracts.
 *
 * `initialize(admin, upgrader, paymentManager, kmsPublicKey)` seeds the base state and grants
 * each AccessControl role to the corresponding signer. Pre-V3 proxies still go through
 * `initializeV3` via the upgrade flow to migrate from Ownable.
 */
export default buildModule("NoxCompute", (m) => {
    const initialAdmin = m.getParameter("initialAdmin");
    const initialUpgrader = m.getParameter("initialUpgrader");
    const initialPaymentManager = m.getParameter("initialPaymentManager");
    const kmsPublicKey = m.getParameter("kmsPublicKey");
    const cuPerOperation = m.getParameter("cuPerOperation", 1);
    const implementation = m.contract("NoxCompute", [cuPerOperation], {
        id: "implementation",
    });
    const initData = m.encodeFunctionCall(implementation, "initialize", [
        initialAdmin,
        initialUpgrader,
        initialPaymentManager,
        kmsPublicKey,
    ]);
    const proxy = m.contract("ERC1967Proxy", [implementation, initData], {
        id: "proxy",
    });
    return { implementation, proxy };
});
