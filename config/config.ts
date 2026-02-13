// CREATE2 deployment salt for deterministic addresses
// TODO: For production deployment, replace with a carefully chosen and documented salt.
// This salt is used by Ignition's create2 strategy to deploy contracts at deterministic addresses.
export const CREATE2_SALT = "0x7a3f9e2b1c8d4f6a5e0b3c7d9f1a2e4b6c8d0f1a3e5b7c9d1f3a5e7b9c1d3f5a" as const;

export default {
    // Default Hardhat network.
    default: {
        chainId: 31337,
        initialOwner: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Hardhat Account #0
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6",
    },
    arbitrumSepolia: {
        chainId: 421614,
        initialOwner: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO: Replace before real deployment
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6", // TODO: Replace before real deployment
    },
    tenderlyArbitrumSepolia: {
        chainId: 421614, // Same chainId as Arbitrum Sepolia
        initialOwner: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO: Replace before real deployment
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6", // TODO: Replace before real deployment
    },
} as {
    [network: string]: {
        chainId: number;
        initialOwner: string;
        kmsPublicKey?: string;
    };
};
