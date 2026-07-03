import { upgrades } from "@openzeppelin/hardhat-upgrades";
import hre from "hardhat";
import connection from "./utils/hardhat-connection-singleton.ts";
import { isHardhatRunCommand } from "./utils/helpers.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";

// Script to import an already-deployed NoxCompute proxy into the OpenZeppelin Upgrades manifest.
// This is needed for proxies deployed via Ignition/CreateX outside of the OZ Upgrades plugin so
// that future `upgradeProxy` calls recognize the proxy and its current implementation.
// forceImport is idempotent and safe to re-run.
//
// Note: Run this from the local source version that matches the implementation CURRENTLY
// deployed on-chain. forceImport records the storage layout from the local `NoxCompute`
// contract. If the local code differs from the deployed implementation, the manifest is
// recorded incorrectly and later upgrade safety checks will be wrong.
//
// Usage: `pnpm run import-proxy-manifest --network <network-name>`

/**
 * Imports the deployed NoxCompute proxy into the OZ Upgrades manifest.
 */
export async function importProxyManifest() {
    console.log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);

    // Read NoxCompute proxy address from ignition deployment artifacts
    const noxComputeProxyAddress = await readDeployedAddress("NoxCompute#proxy");
    console.log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);

    console.log("Importing proxy into the OpenZeppelin upgrades manifest...");
    const api = await upgrades(hre, connection);
    const noxComputeFactory = await connection.ethers.getContractFactory("NoxCompute");
    await api.forceImport(noxComputeProxyAddress, noxComputeFactory, { kind: "uups" });
    console.log("Proxy imported successfully");
}

// Execute the script only if run directly
if (isHardhatRunCommand("scripts/import-proxy-manifest.ts")) {
    await importProxyManifest();
}
