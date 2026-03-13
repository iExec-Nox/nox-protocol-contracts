// CREATE2 deployment salt for deterministic addresses
// TODO: For production deployment, replace with a carefully chosen and documented salt.
// This salt is used by Ignition's create2 strategy to deploy contracts at deterministic addresses.
// TODO use salt config per chain.
export const CREATE2_SALT = "0x7ca392fef4d64c717e8251af66db8361674f99ec878f738bf72f4a9e6074bac1" as const;

export default {
    // Default Hardhat network.
    default: {
        chainId: 31337,
        initialOwner: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266", // Hardhat Account #0
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6",
    },
    arbitrumSepolia: {
        chainId: 421614,
        initialOwner: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        kmsPublicKey: undefined, // Defined in GitHub environment.
    },
    tenderlyArbitrumSepolia: {
        chainId: 421614, // Same chainId as Arbitrum Sepolia
        initialOwner: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO Replace this
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6",
    },
} as {
    [network: string]: {
        chainId: number;
        initialOwner: string;
        kmsPublicKey?: string;
    };
};
