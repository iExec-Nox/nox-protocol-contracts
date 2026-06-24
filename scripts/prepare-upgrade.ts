import { upgrades } from "@openzeppelin/hardhat-upgrades";
import { appendFileSync } from "fs";
import hre from "hardhat";
import { Address, Hex } from "viem";
import connection from "./utils/hardhat-connection-singleton.ts";
import { readDeployedAddress } from "./utils/read-deployed-addresses.ts";

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

    const upgradeData = "0x";
    const proxy = await ethers.getContractAt(contractName, noxComputeProxyAddress);
    const calldata = proxy.interface.encodeFunctionData("upgradeToAndCall", [newImplementation, upgradeData]) as Hex;
    _log(`Upgrade calldata (upgradeToAndCall): ${calldata}`);
    _log("Submit this transaction to the Safe multisig: { to: proxy, value: 0, data: calldata }");

    return { proxyAddress: noxComputeProxyAddress, newImplementation, calldata };
}

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
