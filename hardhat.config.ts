import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
    plugins: [hardhatToolboxViemPlugin],
    ignition: {
        strategyConfig: {
            create2: {
                // TODO: For production deployment, replace with a deterministic salt
                // The salt should be carefully chosen and documented.
                // This random salt is for development only to avoid collisions.
                salt: "0x7a3f9e2b1c8d4f6a5e0b3c7d9f1a2e4b6c8d0f1a3e5b7c9d1f3a5e7b9c1d3f5a",
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
        hardhat: {
            type: "edr-simulated",
            chainType: "l1",
            // Fork Sepolia to have CreateX available at 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed
            forking: {
                url: "https://gateway.tenderly.co/public/sepolia",
            },
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
