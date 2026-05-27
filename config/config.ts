// CREATE2 deployment salt for deterministic addresses
// TODO: For production deployment, replace with a carefully chosen and documented salt.
// This salt is used by Ignition's create2 strategy to deploy contracts at deterministic addresses.
// TODO use salt config per chain.
export const CREATE2_SALT = "0x0000000000000000000000000000000000000000000000000000000000000000" as const;

export default {
    // Default Hardhat network.
    default: {
        chainId: 31337,
        // Hardhat Account #0
        initialAdmin: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
        initialUpgrader: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
        initialPaymentManager: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6",
        // TODO make this 1 when test are updated to make tests paybale by default.
        cuPerOperation: 0,
    },
    tenderlyArbitrumSepolia: {
        chainId: 421614, // Same chainId as Arbitrum Sepolia
        initialAdmin: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO Replace this
        initialUpgrader: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO Replace this
        initialPaymentManager: "0x9990cfb1feb7f47297f54bef4d4ebedf6c5463a3", // TODO Replace this
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6",
        cuPerOperation: 1,
    },
    arbitrumSepolia: {
        chainId: 421614,
        initialAdmin: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        initialUpgrader: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        initialPaymentManager: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        kmsPublicKey: undefined, // Defined in GitHub environment.
        cuPerOperation: 1,
    },
    sepolia: {
        chainId: 11155111,
        initialAdmin: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        initialUpgrader: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        initialPaymentManager: "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f",
        kmsPublicKey: undefined, // Defined in GitHub environment.
        cuPerOperation: 1,
    },
    ethereum: {
        chainId: 1,
        initialAdmin: "", // TODO Replace this
        initialUpgrader: "", // TODO Replace this
        initialPaymentManager: "", // TODO Replace this
        kmsPublicKey: undefined, // Defined in GitHub environment.
        cuPerOperation: 1,
    },
} as {
    [network: string]: {
        chainId: number;
        // Role addresses passed to `initializeV3`.
        initialAdmin: string;
        initialUpgrader: string;
        initialPaymentManager: string;
        kmsPublicKey?: string;
        cuPerOperation: number;
    };
};
