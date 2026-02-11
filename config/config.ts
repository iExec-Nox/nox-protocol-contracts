// CreateX factory address (deterministically deployed at this address on all EVM chains)
export const CREATEX_ADDRESS = "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed" as const;

// CREATE2 deployment salt for deterministic addresses
// TODO: For production deployment, replace with a carefully chosen and documented salt.
// This salt is used by Ignition's create2 strategy to deploy contracts at deterministic addresses.
export const CREATE2_SALT = "0x7a3f9e2b1c8d4f6a5e0b3c7d9f1a2e4b6c8d0f1a3e5b7c9d1f3a5e7b9c1d3f5a" as const;

export default {
    // Default Hardhat network.
    default: {
        chainId: 31337,
        initialOwner: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Hardhat Account #0
    },
    arbitrumSepolia: {
        chainId: 421614,
        initialOwner: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO: Replace before real deployment
    },
    tenderlyArbitrumSepolia: {
        chainId: 421614, // Same chainId as Arbitrum Sepolia
        initialOwner: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO: Replace before real deployment
    },
} as {
    [network: string]: {
        chainId: number;
        initialOwner: string;
    };
};
