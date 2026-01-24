export default {
    // Default Hardhat network.
    default: {
        chainId: 31337,
        initialOwner: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Hardhat Account #0
    },
    arbitrumSepolia: {
        chainId: 421614,
        initialOwner: "TODO",
    },
    tenderlyVirtualArbitrumSepolia: {
        chainId: 421614, // Same chainId as Arbitrum Sepolia
        initialOwner: "TODO",
    },
} as {
    [network: string]: {
        chainId: number;
        initialOwner: string;
    };
};
