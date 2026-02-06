// CreateX factory address (deterministically deployed at this address on all EVM chains)
export const CREATEX_ADDRESS = "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed" as const;

// Hardcoded addresses matching TEEPrimitives.sol
// These addresses must match the constants in contracts/lib/TEEPrimitives.sol
export const TEE_COMPUTE_MANAGER_ADDRESS = "0xf07E9032F06E44e2c04930484aD0C8865779e08e" as const;
export const ACL_ADDRESS = "0x8bEa38F8915c35E61bd3c95a23A7370d5B344F7b" as const;

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
