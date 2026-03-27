import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import openzeppelinUpgradesPlugin from "@openzeppelin/hardhat-upgrades";
import { proxyFilesToBuild } from "@openzeppelin/hardhat-upgrades";
import { configVariable, defineConfig } from "hardhat/config";
import { CREATE2_SALT } from "./config/config.ts";
import solc from "./.solc.json" with { type: "json" };

setOpenzeppelingUpgradesConfig();

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
    plugins: [hardhatToolboxViemPlugin, openzeppelinUpgradesPlugin],
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
        arbitrumSepolia: {
            type: "http",
            chainType: "op",
            chainId: 421614,
            url: "http://localhost:8545",
            accounts: [],
        },
        tenderlyArbitrumSepolia: {
            type: "http",
            chainType: "op",
            chainId: 421614,
            url: "http://localhost:8545",
            accounts: [],
        },
    },
});

/**
 * Set manifest file path for OZ upgrades plugin.
 * This is a fix to use different .openzeppelin manifest files for Arbitrum Sepolia and
 * its forks (tenderlyArbitrumSepolia) as its chainId is not recognized by the plugin.
 */
function setOpenzeppelingUpgradesConfig() {
    const networkArgIndex = process.argv.indexOf("--network");
    if (networkArgIndex !== -1) {
        process.env.MANIFEST_DEFAULT_DIR ??= `.openzeppelin/${process.argv[networkArgIndex + 1]}`;
    }
}
