import { upgrades } from "@openzeppelin/hardhat-upgrades";
import { appendFileSync } from "fs";
import hre from "hardhat";
import { Address } from "viem";
import connection from "./utils/hardhat-connection-singleton.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";

/**
 * Prepares a NoxCompute proxy upgrade for a Safe multisig proposal.
 * Should be updated and adapted for each upgrade.
 * @param proxyAddress the NoxCompute proxy address to upgrade, resolved automatically if not provided
 * @param printLogs whether to print logs or not
 * @param contractName the contract to deploy as new implementation (defaults to "NoxCompute")
 * @returns The proxy address, the new implementation address and the `upgradeToAndCall` calldata
 */
export async function prepareUpgradeNoxCompute(proxyAddress?: Address, printLogs = true, contractName = "NoxCompute") {
    const _log = printLogs ? console.log : () => {};
    const { ethers } = connection;
    const [proposer] = await ethers.getSigners();

    _log(`Preparing NoxCompute upgrade (Safe multisig proposal)`);
    _log(`New implementation contract: ${contractName}`);
    _log(`Network: ${connection.networkName} (chainId: ${connection.networkConfig.chainId})`);
    _log(`Proposer/deployer address: ${proposer?.address}`);

    const noxComputeProxyAddress = (proxyAddress ?? (await readDeployedAddress("NoxCompute#proxy"))) as Address;
    _log(`NoxCompute proxy address: ${noxComputeProxyAddress}`);

    const api = await upgrades(hre, connection);
    const newImplFactory = await ethers.getContractFactory(contractName);

    const newImplementation = (await api.prepareUpgrade(noxComputeProxyAddress, newImplFactory, {
        unsafeAllow: ["constructor"],
    })) as Address;
    _log(`New implementation deployed at: ${newImplementation}`);

    // Encode the UUPS upgrade calldata: `upgradeToAndCall(newImplementation, data)`.
    // `data` is empty unless a reinitializer must run atomically as part of the upgrade.
    const upgradeData = "0x";
    const proxy = await ethers.getContractAt(contractName, noxComputeProxyAddress);
    const calldata = proxy.interface.encodeFunctionData("upgradeToAndCall", [
        newImplementation,
        upgradeData,
    ]) as Address;
    _log(`Upgrade calldata (upgradeToAndCall): ${calldata}`);
    _log("Submit this transaction to the Safe multisig: { to: proxy, value: 0, data: calldata }");

    return { proxyAddress: noxComputeProxyAddress, newImplementation, calldata };
}

// Execute the script only if run directly
if (_isHardhatRunCommand()) {
    const { proxyAddress, newImplementation, calldata } = await prepareUpgradeNoxCompute();

    // Expose results to the GitHub Actions workflow that proposes the Safe transaction.
    const githubOutput = process.env.GITHUB_OUTPUT;
    if (githubOutput) {
        appendFileSync(githubOutput, `transaction-to=${proxyAddress}\n`);
        appendFileSync(githubOutput, `transaction-data=${calldata}\n`);
        appendFileSync(githubOutput, `new-implementation=${newImplementation}\n`);
    }
}

function _isHardhatRunCommand() {
    return (
        process.argv.length >= 4 && process.argv[2] === "run" && process.argv[3].includes("scripts/prepare-upgrade.ts")
    );
}
