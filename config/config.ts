// CreateX factory address (deterministically deployed at this address on all EVM chains)
export const CREATEX_ADDRESS = "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed" as const;

// Hardcoded addresses matching TEEPrimitives.sol
// These addresses must match the constants in contracts/lib/TEEPrimitives.sol
export const TEE_COMPUTE_MANAGER_ADDRESS = "0x029Ab6663e4F73477494082EB88915ea74Df5e83" as const;
export const ACL_ADDRESS = "0x310163c93461AB5c6445044B15B0DA1784b595FB" as const;

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
