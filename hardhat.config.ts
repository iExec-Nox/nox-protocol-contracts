import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";
import { CREATE2_SALT } from "./config/config.js";

export default defineConfig({
    plugins: [hardhatToolboxViemPlugin],
    ignition: {
        strategyConfig: {
            create2: {
                salt: CREATE2_SALT,
            },
        },
    },
    solidity: {
        profiles: {
            default: {
                version: "0.8.28",
            },
            production: {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    viaIR: true,
                },
            },
        },
        npmFilesToBuild: ["@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol", "createx/src/ICreateX.sol"],
    },
    networks: {
        default: {
            type: "edr-simulated",
            chainType: "op",
        },
        arbitrumSepolia: {
            type: "http",
            chainType: "op",
            chainId: 421614,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("DEPLOYER_PRIVATE_KEY")],
        },
        tenderlyArbitrumSepolia: {
            type: "http",
            chainType: "op",
            chainId: 421614,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("DEPLOYER_PRIVATE_KEY")],
        },
    },
});
