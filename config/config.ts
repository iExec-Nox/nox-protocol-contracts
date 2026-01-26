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
