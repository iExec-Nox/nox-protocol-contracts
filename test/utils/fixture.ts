import hre from "hardhat";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { encodeAbiParameters, keccak256, toHex, concat, getContract, Abi } from "viem";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";

// CreateX factory address (same on all EVM chains)
const CREATEX_ADDRESS = "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed" as const;

// Hardcoded addresses matching TEEPrimitives.sol
// These addresses must match the constants in TEEPrimitives.sol for integration tests to work
const TEE_COMPUTE_MANAGER_ADDRESS = "0x029Ab6663e4F73477494082EB88915ea74Df5e83" as const;
const ACL_ADDRESS = "0x310163c93461AB5c6445044B15B0DA1784b595FB" as const;

// Cached CreateX ABI (loaded once from artifact)
let createXAbi: Abi | null = null;

async function getCreateXAbi(): Promise<Abi> {
    if (!createXAbi) {
        const artifact = await hre.artifacts.readArtifact("ICreateX");
        createXAbi = artifact.abi as Abi;
    }
    return createXAbi;
}

// Module-level cache for the fixture to avoid re-deployment
let cachedFixture: Awaited<ReturnType<typeof deployFixture>> | null = null;
let snapshotId: string | null = null;

export async function loadFixture() {
    const publicClient = await connection.viem.getPublicClient();

    // If we have a cached fixture, restore the snapshot and return cached data
    if (cachedFixture && snapshotId) {
        // Revert to snapshot to get clean state
        await publicClient.request({
            method: "evm_revert" as any,
            params: [snapshotId],
        });
        // Take a new snapshot for the next test
        snapshotId = await publicClient.request({
            method: "evm_snapshot" as any,
            params: [],
        });
        return cachedFixture;
    }

    // First call - deploy and cache
    cachedFixture = await deployFixture();
    // Take snapshot after deployment
    snapshotId = await publicClient.request({
        method: "evm_snapshot" as any,
        params: [],
    });
    return cachedFixture;
}

/**
 * Generates unique salts for deployment to avoid CREATE2 collisions.
 */
function generateSalts() {
    // Use a unique prefix based on current time to avoid collisions with any existing contracts
    const uniquePrefix = keccak256(toHex(Date.now().toString() + Math.random().toString()));
    return {
        aclImpl: keccak256(concat([uniquePrefix, toHex("acl.impl")])),
        aclProxy: keccak256(concat([uniquePrefix, toHex("acl.proxy")])),
        teeImpl: keccak256(concat([uniquePrefix, toHex("tee.impl")])),
        teeProxy: keccak256(concat([uniquePrefix, toHex("tee.proxy")])),
    };
}

/**
 * Deploys contracts using CreateX.
 * Uses unique salts per deployment to avoid collisions.
 * Requires Sepolia fork (or any network where CreateX is deployed).
 */
async function deployFixture() {
    const viem = connection.viem;
    const publicClient = await viem.getPublicClient();
    const accounts = await viem.getWalletClients();
    const deployer = accounts[0];

    // Generate unique salts for this deployment
    const salts = generateSalts();

    // Get contract artifacts for bytecode
    const aclArtifact = await hre.artifacts.readArtifact("ACL");
    const teeComputeManagerArtifact = await hre.artifacts.readArtifact("TEEComputeManager");
    const erc1967ProxyArtifact = await hre.artifacts.readArtifact("ERC1967Proxy");
    const createXAbi = await getCreateXAbi();

    // Check if CreateX is available on this network
    const createXCode = await publicClient.getCode({ address: CREATEX_ADDRESS });
    if (!createXCode || createXCode === "0x") {
        throw new Error("CreateX not found at expected address. Ensure network is forking from Sepolia.");
    }

    // Deploy ACL implementation via CreateX
    const aclImplTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [salts.aclImpl, aclArtifact.bytecode as `0x${string}`],
    });
    const aclImplReceipt = await publicClient.waitForTransactionReceipt({ hash: aclImplTx });
    const aclImplementation = getDeployedAddress(aclImplReceipt);

    // Deploy ACL proxy via CreateX WITHOUT init data
    const aclProxyInitCode = encodeProxyInitCode(
        erc1967ProxyArtifact.bytecode as `0x${string}`,
        aclImplementation,
        "0x",
    );
    const aclProxyTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [salts.aclProxy, aclProxyInitCode],
    });
    const aclProxyReceipt = await publicClient.waitForTransactionReceipt({ hash: aclProxyTx });
    const aclProxyAddress = getDeployedAddress(aclProxyReceipt);

    // Deploy TEEComputeManager implementation via CreateX (with ACL as constructor arg)
    const teeImplInitCode = encodeContractWithArgs(teeComputeManagerArtifact.bytecode as `0x${string}`, [
        { type: "address", value: aclProxyAddress },
    ]);
    const teeImplTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [salts.teeImpl, teeImplInitCode],
    });
    const teeImplReceipt = await publicClient.waitForTransactionReceipt({ hash: teeImplTx });
    const teeImplementation = getDeployedAddress(teeImplReceipt);

    // Deploy TEEComputeManager proxy via CreateX WITHOUT init data
    const teeProxyInitCode = encodeProxyInitCode(
        erc1967ProxyArtifact.bytecode as `0x${string}`,
        teeImplementation,
        "0x",
    );
    const teeProxyTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [salts.teeProxy, teeProxyInitCode],
    });
    const teeProxyReceipt = await publicClient.waitForTransactionReceipt({ hash: teeProxyTx });
    const teeProxyAddress = getDeployedAddress(teeProxyReceipt);

    // Get contract instances at deployed addresses
    const acl = await viem.getContractAt("ACL", aclProxyAddress);
    const teeComputeManager = await viem.getContractAt("TEEComputeManager", teeProxyAddress);

    // Initialize contracts
    const initAclTx = await acl.write.initialize([deployer.account.address]);
    await publicClient.waitForTransactionReceipt({ hash: initAclTx });
    const initTeeTx = await teeComputeManager.write.initialize([deployer.account.address]);
    await publicClient.waitForTransactionReceipt({ hash: initTeeTx });

    // Configure contracts
    const setTeeManagerTx = await acl.write.setTeeComputeManager([teeProxyAddress]);
    await publicClient.waitForTransactionReceipt({ hash: setTeeManagerTx });

    // Set up gateway
    const gateway = privateKeyToAccount(generatePrivateKey());
    const setGatewayTx = await teeComputeManager.write.setGateway([gateway.address]);
    await publicClient.waitForTransactionReceipt({ hash: setGatewayTx });

    // Deploy contracts at the hardcoded addresses used by TEEPrimitives
    // This is necessary for integration tests that use contracts depending on TEEPrimitives
    // We need fresh implementations with correct immutables pointing to hardcoded addresses
    await deployAtHardcodedAddresses(viem, publicClient, deployer, gateway.address);

    // Get references to contracts at hardcoded addresses (for integration tests using TEEPrimitives)
    const aclAtHardcoded = await viem.getContractAt("ACL", ACL_ADDRESS);
    const teeComputeManagerAtHardcoded = await viem.getContractAt("TEEComputeManager", TEE_COMPUTE_MANAGER_ADDRESS);

    return {
        // Dynamically deployed contracts (for unit tests that don't use TEEPrimitives)
        acl,
        // Contracts at hardcoded addresses (for integration tests using TEEPrimitives)
        aclAtHardcodedAddress: aclAtHardcoded,
        teeComputeManager: teeComputeManagerAtHardcoded,
        // Accounts
        admin: accounts[0],
        wallet1: accounts[1],
        wallet2: accounts[2],
        wallet3: accounts[3],
        wallet4: accounts[4],
        gateway,
    };
}

// ERC1967 implementation slot
const IMPLEMENTATION_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" as const;

/**
 * Deploys fresh contracts at the hardcoded addresses used by TEEPrimitives.
 * This creates new implementations with correct immutables pointing to hardcoded addresses.
 */
async function deployAtHardcodedAddresses(
    viem: Awaited<ReturnType<typeof connection.viem.getPublicClient>>["chain"] extends undefined
        ? never
        : typeof connection.viem,
    publicClient: Awaited<ReturnType<typeof connection.viem.getPublicClient>>,
    deployer: Awaited<ReturnType<typeof connection.viem.getWalletClients>>[0],
    gatewayAddress: `0x${string}`,
) {
    // Get contract artifacts
    const aclArtifact = await hre.artifacts.readArtifact("ACL");
    const teeComputeManagerArtifact = await hre.artifacts.readArtifact("TEEComputeManager");
    const erc1967ProxyArtifact = await hre.artifacts.readArtifact("ERC1967Proxy");
    const createXAbi = await getCreateXAbi();

    // Deploy ACL implementation
    const aclImplTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [keccak256(toHex("hardcoded.acl.impl")), aclArtifact.bytecode as `0x${string}`],
    });
    const aclImplReceipt = await publicClient.waitForTransactionReceipt({ hash: aclImplTx });
    const aclImplementation = getDeployedAddress(aclImplReceipt);

    // Create ACL proxy bytecode and etch it at the hardcoded address
    const aclProxyInitCode = encodeProxyInitCode(
        erc1967ProxyArtifact.bytecode as `0x${string}`,
        aclImplementation,
        "0x",
    );
    // Deploy temp proxy to get runtime bytecode
    const aclProxyTempTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [keccak256(toHex("hardcoded.acl.proxy.temp")), aclProxyInitCode],
    });
    const aclProxyTempReceipt = await publicClient.waitForTransactionReceipt({ hash: aclProxyTempTx });
    const aclProxyTempAddress = getDeployedAddress(aclProxyTempReceipt);

    // Copy the temp proxy bytecode to the hardcoded address
    const aclProxyBytecode = await publicClient.getCode({ address: aclProxyTempAddress });
    await publicClient.request({
        method: "hardhat_setCode" as any,
        params: [ACL_ADDRESS, aclProxyBytecode!],
    });
    // Set implementation slot
    const aclImplPadded = aclImplementation.slice(2).toLowerCase().padStart(64, "0");
    await publicClient.request({
        method: "hardhat_setStorageAt" as any,
        params: [ACL_ADDRESS, IMPLEMENTATION_SLOT, `0x${aclImplPadded}`],
    });

    // Initialize ACL at hardcoded address
    const aclAtHardcoded = await viem.getContractAt("ACL", ACL_ADDRESS);
    const initAclTx = await aclAtHardcoded.write.initialize([deployer.account.address]);
    await publicClient.waitForTransactionReceipt({ hash: initAclTx });

    // Deploy TEEComputeManager implementation WITH THE HARDCODED ACL ADDRESS as immutable
    const teeImplInitCode = encodeContractWithArgs(teeComputeManagerArtifact.bytecode as `0x${string}`, [
        { type: "address", value: ACL_ADDRESS }, // Use hardcoded ACL address!
    ]);
    const teeImplTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [keccak256(toHex("hardcoded.tee.impl")), teeImplInitCode],
    });
    const teeImplReceipt = await publicClient.waitForTransactionReceipt({ hash: teeImplTx });
    const teeImplementation = getDeployedAddress(teeImplReceipt);

    // Create TEEComputeManager proxy bytecode and etch it at the hardcoded address
    const teeProxyInitCode = encodeProxyInitCode(
        erc1967ProxyArtifact.bytecode as `0x${string}`,
        teeImplementation,
        "0x",
    );
    // Deploy temp proxy to get runtime bytecode
    const teeProxyTempTx = await deployer.writeContract({
        address: CREATEX_ADDRESS,
        abi: createXAbi,
        functionName: "deployCreate2",
        args: [keccak256(toHex("hardcoded.tee.proxy.temp")), teeProxyInitCode],
    });
    const teeProxyTempReceipt = await publicClient.waitForTransactionReceipt({ hash: teeProxyTempTx });
    const teeProxyTempAddress = getDeployedAddress(teeProxyTempReceipt);

    // Copy the temp proxy bytecode to the hardcoded address
    const teeProxyBytecode = await publicClient.getCode({ address: teeProxyTempAddress });
    await publicClient.request({
        method: "hardhat_setCode" as any,
        params: [TEE_COMPUTE_MANAGER_ADDRESS, teeProxyBytecode!],
    });
    // Set implementation slot
    const teeImplPadded = teeImplementation.slice(2).toLowerCase().padStart(64, "0");
    await publicClient.request({
        method: "hardhat_setStorageAt" as any,
        params: [TEE_COMPUTE_MANAGER_ADDRESS, IMPLEMENTATION_SLOT, `0x${teeImplPadded}`],
    });

    // Initialize TEEComputeManager at hardcoded address
    const teeAtHardcoded = await viem.getContractAt("TEEComputeManager", TEE_COMPUTE_MANAGER_ADDRESS);
    const initTeeTx = await teeAtHardcoded.write.initialize([deployer.account.address]);
    await publicClient.waitForTransactionReceipt({ hash: initTeeTx });

    // Configure contracts at hardcoded addresses
    const setTeeTx = await aclAtHardcoded.write.setTeeComputeManager([TEE_COMPUTE_MANAGER_ADDRESS]);
    await publicClient.waitForTransactionReceipt({ hash: setTeeTx });

    const setGatewayTx = await teeAtHardcoded.write.setGateway([gatewayAddress]);
    await publicClient.waitForTransactionReceipt({ hash: setGatewayTx });
}

/**
 * Encodes contract bytecode with constructor arguments.
 */
function encodeContractWithArgs(bytecode: `0x${string}`, args: Array<{ type: string; value: unknown }>): `0x${string}` {
    const types = args.map((arg) => ({ type: arg.type }));
    const values = args.map((arg) => arg.value);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const encodedArgs = encodeAbiParameters(types as any, values as any);
    return `${bytecode}${encodedArgs.slice(2)}` as `0x${string}`;
}

/**
 * Encodes ERC1967Proxy creation bytecode with constructor arguments.
 */
function encodeProxyInitCode(
    proxyBytecode: `0x${string}`,
    implementation: `0x${string}`,
    initData: `0x${string}`,
): `0x${string}` {
    const encodedArgs = encodeAbiParameters([{ type: "address" }, { type: "bytes" }], [implementation, initData]);
    return `${proxyBytecode}${encodedArgs.slice(2)}` as `0x${string}`;
}

// CreateX ContractCreation(address indexed newContract, bytes32 indexed salt) event signature
const CREATEX_CONTRACT_CREATION_EVENT = "0xb8fda7e00c6b06a2b54e58521bc5894fee35f1090e5a3bb6390bfe2b98b497f7";

/**
 * Extracts deployed contract address from transaction receipt.
 * CreateX emits a ContractCreation event with the new address.
 */
function getDeployedAddress(receipt: { logs: Array<{ topics: readonly string[]; data: string }> }): `0x${string}` {
    // Find the CreateX ContractCreation event specifically
    for (const log of receipt.logs) {
        const topic0 = log.topics[0]?.toLowerCase();
        const expected = CREATEX_CONTRACT_CREATION_EVENT.toLowerCase();
        if (topic0 === expected && log.topics.length >= 2) {
            // Extract address from topic (last 20 bytes of 32-byte topic)
            const addressTopic = log.topics[1];
            if (addressTopic) {
                return `0x${addressTopic.slice(-40)}` as `0x${string}`;
            }
        }
    }
    throw new Error("Could not find CreateX ContractCreation event in transaction receipt");
}
