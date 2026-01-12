export default {
    // Default Hardhat network.
    default: {
        chainId: 31337,
        initialAdmin: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Hardhat Account #0
        initialUpgrader: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Hardhat Account #0
    },
    sepolia: {
        chainId: 11155111,
        initialAdmin: "TODO",
        initialUpgrader: "TODO",
    },
} as {
    [network: string]: {
        chainId: number;
        initialAdmin: string;
        initialUpgrader: string;
    };
};
