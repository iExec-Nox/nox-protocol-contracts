// A mock service to simulate the Gateway and the Runner.

import { randomBytes } from "crypto";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import { concatHex, Log, parseAbiItem, PrivateKeyAccount, toHex, WatchEventReturnType } from "viem";

const AddEvent = parseAbiItem(
    "event Add(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
);

let running = false;
let stopGatewayService: WatchEventReturnType;

export async function startOffChainServices(teeComputeManagerAddress: `0x${string}`) {
    if (running) {
        throw new Error("Mock services are already running");
    }
    running = true;
    stopGatewayService = await startGateway(teeComputeManagerAddress);
}

export async function stopOffChainServices() {
    if (!running) {
        throw new Error("Mock services are not running");
    }
    running = false;
    stopGatewayService();
}

async function startGateway(teeComputeManagerAddress: `0x${string}`) {
    console.log("📡 Gateway service mock started");
    const client = await connection.viem.getPublicClient();
    const unwatch = client.watchEvent({
        address: teeComputeManagerAddress,
        event: AddEvent,
        onLogs: (logs) => {
            console.log("received event");
            for (const log of logs) {
                processEvent(log);
            }
        },
        onError(error) {
            console.error("❌ Event listener error", error);
        },
    });
    process.on("SIGINT", () => {
        unwatch();
        process.exit();
    });
    return unwatch;
}

function processEvent(log: Log<bigint, number, false, typeof AddEvent>) {
    const { caller, leftHandOperand, rightHandOperand, result } = log.args;
    console.log("🧾 Add event");
    console.log({
        caller,
        leftHandOperand,
        rightHandOperand,
        result,
        txHash: log.transactionHash,
        blockNumber: log.blockNumber,
    });
}

export function createHandle(chainId: number, teeType: number): `0x${string}` {
    const preHandle = toHex(randomBytes(26));
    const chainIdBytes = toHex(chainId, { size: 4 });
    const teeTypeByte = toHex(teeType, { size: 1 });
    const versionByte = toHex(0, { size: 1 });
    return concatHex([preHandle, chainIdBytes, teeTypeByte, versionByte]);
}

export async function createHandleAndProof(
    value: number,
    teeType: number,
    chainId: number,
    userAddress: `0x${string}`,
    appAddress: `0x${string}`,
    gateway: PrivateKeyAccount,
    teeComputeManagerAddress: `0x${string}`,
): Promise<{ handle: `0x${string}`; proof: `0x${string}` }> {
    const createdAt = BigInt(Math.floor(Date.now() / 1000)); // in seconds
    const handle = createHandle(Number(chainId), teeType);

    const domain = {
        name: "TEEComputeManager",
        version: "1",
        chainId,
        verifyingContract: teeComputeManagerAddress,
    } as const;
    const types = {
        HandleProof: [
            { name: "handle", type: "bytes32" },
            { name: "owner", type: "address" },
            { name: "app", type: "address" },
            { name: "createdAt", type: "uint256" },
        ],
    } as const;
    const message = {
        handle,
        owner: userAddress,
        app: appAddress,
        createdAt,
    } as const;

    const signature = await gateway.signTypedData({
        domain,
        types,
        primaryType: "HandleProof",
        message,
    });
    const proof = concatHex([userAddress, appAddress, toHex(createdAt, { size: 32 }), signature]);
    return { handle, proof };
}
