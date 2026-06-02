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
        kmsPublicKey: "0x026f0005c5c3807e69dcbe52a97ca55aa26c8655999b5a81f5098666cd7dd5d1f6",
        gateway: "0xE13191F53671957C8a48A7A3Ff15E16450a1552F",
    },
    tenderlyArbitrumSepolia: {
        chainId: 421614,
        initialAdmin: "0x40D03906B889AbF57266C2433B0b200177D15664",
        initialUpgrader: "0x6148045F5281af51Dde61E9072bf8a53004a34c0",
        kmsPublicKey: "0x02221f1baca89fd75ec26566b9c6003bc793b47affe171a7824279d973f54a2fd9",
        gateway: "0xE13191F53671957C8a48A7A3Ff15E16450a1552F",
    },
    arbitrumSepolia: {
        chainId: 421614,
        initialAdmin: "0x40D03906B889AbF57266C2433B0b200177D15664",
        initialUpgrader: "0x6148045F5281af51Dde61E9072bf8a53004a34c0",
        kmsPublicKey: "0x02221f1baca89fd75ec26566b9c6003bc793b47affe171a7824279d973f54a2fd9",
        gateway: "0xE13191F53671957C8a48A7A3Ff15E16450a1552F",
    },
    sepolia: {
        chainId: 11155111,
        initialAdmin: "0xD45e79Cd834427A8fE3f1Ed406C0781c17335eDb",
        initialUpgrader: "0xC0Ed057C8819b2b00e93B8b22Ff61b7e0269D6A5",
        kmsPublicKey: "0x12e1b0794046ef04bfae49938c1293fabbd6614c04862a4059d5e8a0911635c2",
        gateway: "0xE13191F53671957C8a48A7A3Ff15E16450a1552F",
    },
    ethereum: {
        chainId: 1,
        initialAdmin: "", // TODO Replace this
        initialUpgrader: "", // TODO Replace this
        kmsPublicKey: "", // TODO Replace this
        gateway: "", // TODO Replace this
    },
} as {
    [network: string]: {
        chainId: number;
        // Role addresses passed to `initialize` / `initializeV3`.
        initialAdmin: string;
        initialUpgrader: string;
        kmsPublicKey: string;
        gateway: string;
    };
};
