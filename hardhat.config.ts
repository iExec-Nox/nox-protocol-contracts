import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import hardhatEthersPlugin from "@nomicfoundation/hardhat-ethers"; // used by OpenZeppelin Upgrades plugin.
import openzeppelinUpgradesPlugin from "@openzeppelin/hardhat-upgrades";
import { proxyFilesToBuild } from "@openzeppelin/hardhat-upgrades";
import { configVariable, defineConfig } from "hardhat/config";
import { CREATE2_SALT } from "./config/config.ts";
import solc from "./.solc.json" with { type: "json" };

const baseProfile = {
    version: solc.version,
    settings: {
        evmVersion: "osaka",
        metadata: {
            bytecodeHash: "none",
        },
    },
} as const;

export default defineConfig({
    plugins: [hardhatToolboxViemPlugin, hardhatEthersPlugin, openzeppelinUpgradesPlugin],
    ignition: {
        strategyConfig: {
            create2: {
                salt: CREATE2_SALT,
            },
        },
    },
    solidity: {
        profiles: {
            default: baseProfile,
            production: {
                version: baseProfile.version,
                settings: {
                    ...baseProfile.settings,
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    viaIR: true,
                },
            },
        },
        npmFilesToBuild: proxyFilesToBuild(),
    },
    verify: {
        etherscan: {
            apiKey: configVariable("ETHERSCAN_API_KEY"),
        },
    },
    networks: {
        default: {
            type: "edr-simulated",
            chainType: "op",
            allowUnlimitedContractSize: true,
        },
        tenderlyArbitrumSepolia: {
            type: "http",
            chainType: "op",
            chainId: 421614,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("PRIVATE_KEY")],
        },
        arbitrumSepolia: {
            type: "http",
            chainType: "op",
            chainId: 421614,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("PRIVATE_KEY")],
        },
        sepolia: {
            type: "http",
            chainType: "l1",
            chainId: 11155111,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("PRIVATE_KEY")],
        },
        ethereum: {
            type: "http",
            chainType: "l1",
            chainId: 1,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("PRIVATE_KEY")],
        },
    },
});
