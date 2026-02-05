import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { deploy } from "../../scripts/deploy.js";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";

// Hardcoded addresses from TEEPrimitives.sol - MUST match exactly
const TEE_COMPUTE_MANAGER_ADDRESS = "0x029Ab6663e4F73477494082EB88915ea74Df5e83";
const ACL_ADDRESS = "0x310163c93461AB5c6445044B15B0DA1784b595FB";

// ERC1967 implementation slot
const IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";

// OpenZeppelin v5 storage slots for upgradeable contracts
// OwnableUpgradeable storage slot (keccak256("openzeppelin.storage.Ownable") - 1)
const OWNABLE_STORAGE_SLOT = "0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300";
// Initializable storage slot (keccak256("openzeppelin.storage.Initializable") - 1)
const INITIALIZABLE_STORAGE_SLOT = "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00";

// EIP712Upgradeable storage slots (base + offsets for struct fields)
// Base: keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.EIP712")) - 1)) & ~bytes32(uint256(0xff))
const EIP712_STORAGE_SLOTS = [
    "0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d100", // _hashedName
    "0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d101", // _hashedVersion
    "0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d102", // _name (string pointer)
    "0xa16a46d94261c7517cc8ff89f61c0ce93598e3c849801011dee649a6a557d103", // _version (string pointer)
];

export async function loadFixture() {
    return await connection.networkHelpers.loadFixture(deployFixture);
}

/**
 * This function defines the fixture to deploy for tests. Update this function when needed.
 */
async function deployFixture() {
    const viem = connection.viem;
    const publicClient = await viem.getPublicClient();

    // Deploy contracts (on local network they won't be at deterministic addresses)
    const deployment = await deploy(false);

    // Copy ACL bytecode and storage to hardcoded address
    await copyContractToAddress(deployment.acl.address, ACL_ADDRESS, [
        IMPLEMENTATION_SLOT,
        OWNABLE_STORAGE_SLOT,
        INITIALIZABLE_STORAGE_SLOT,
    ]);

    // For TEEComputeManager, we need to deploy a new implementation with the hardcoded ACL address
    // because ACL is an immutable that's baked into the bytecode
    await deployTeeComputeManagerAtHardcodedAddress(deployment.teeComputeManager.address);

    // Get contract instances at the hardcoded addresses
    const acl = await viem.getContractAt("ACL", ACL_ADDRESS);
    const teeComputeManager = await viem.getContractAt("TEEComputeManager", TEE_COMPUTE_MANAGER_ADDRESS);

    // Update ACL's teeComputeManager reference to point to the hardcoded address
    const setTeeManagerTx = await acl.write.setTeeComputeManager([TEE_COMPUTE_MANAGER_ADDRESS]);
    await publicClient.waitForTransactionReceipt({ hash: setTeeManagerTx });

    // Set up gateway
    const accounts = await viem.getWalletClients();
    const gateway = privateKeyToAccount(generatePrivateKey());
    const tx = await teeComputeManager.write.setGateway([gateway.address]);
    await publicClient.waitForTransactionReceipt({ hash: tx });

    return {
        acl,
        teeComputeManager,
        admin: accounts[0],
        wallet1: accounts[1],
        wallet2: accounts[2],
        wallet3: accounts[3],
        wallet4: accounts[4],
        gateway,
    };
}

/**
 * Copies contract bytecode and storage from source to target address.
 * This allows TEEPrimitives library to work on local networks.
 */
async function copyContractToAddress(sourceAddress: string, targetAddress: string, storageSlots: string[]) {
    const publicClient = await connection.viem.getPublicClient();

    // Get bytecode from source
    const bytecode = await publicClient.getCode({ address: sourceAddress as `0x${string}` });
    if (!bytecode) {
        throw new Error(`No bytecode at source address: ${sourceAddress}`);
    }

    // Set bytecode at target address
    await publicClient.request({
        method: "hardhat_setCode" as any,
        params: [targetAddress, bytecode],
    });

    // Copy all specified storage slots
    for (const slot of storageSlots) {
        const value = await publicClient.getStorageAt({
            address: sourceAddress as `0x${string}`,
            slot: slot as `0x${string}`,
        });

        if (value) {
            await publicClient.request({
                method: "hardhat_setStorageAt" as any,
                params: [targetAddress, slot, value],
            });
        }
    }
}

/**
 * Deploys TEEComputeManager at the hardcoded address with the correct ACL immutable.
 * We need to deploy a new implementation because ACL is an immutable baked into bytecode.
 */
async function deployTeeComputeManagerAtHardcodedAddress(sourceProxyAddress: string) {
    const viem = connection.viem;
    const publicClient = await viem.getPublicClient();

    // Deploy a new implementation with the hardcoded ACL address
    const teeComputeManagerImpl = await viem.deployContract("TEEComputeManager", [ACL_ADDRESS]);

    // Deploy a temporary proxy using OpenZeppelin's ERC1967Proxy
    const tempProxy = await viem.deployContract("@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy", [
        teeComputeManagerImpl.address,
        "0x",
    ]);

    // Get the proxy bytecode
    const proxyBytecode = await publicClient.getCode({ address: tempProxy.address });
    if (!proxyBytecode) {
        throw new Error("Failed to get proxy bytecode");
    }

    // Set the proxy bytecode at the hardcoded address
    await publicClient.request({
        method: "hardhat_setCode" as any,
        params: [TEE_COMPUTE_MANAGER_ADDRESS, proxyBytecode],
    });

    // Set the implementation slot to point to our new implementation
    const implAddressWithoutPrefix = teeComputeManagerImpl.address.slice(2).toLowerCase();
    const implAddressPadded = `0x${implAddressWithoutPrefix.padStart(64, "0")}`;
    await publicClient.request({
        method: "hardhat_setStorageAt" as any,
        params: [TEE_COMPUTE_MANAGER_ADDRESS, IMPLEMENTATION_SLOT, implAddressPadded],
    });

    // Copy owner and initializable storage from source
    for (const slot of [OWNABLE_STORAGE_SLOT, INITIALIZABLE_STORAGE_SLOT, ...EIP712_STORAGE_SLOTS]) {
        const value = await publicClient.getStorageAt({
            address: sourceProxyAddress as `0x${string}`,
            slot: slot as `0x${string}`,
        });
        if (value) {
            await publicClient.request({
                method: "hardhat_setStorageAt" as any,
                params: [TEE_COMPUTE_MANAGER_ADDRESS, slot, value],
            });
        }
    }
}
