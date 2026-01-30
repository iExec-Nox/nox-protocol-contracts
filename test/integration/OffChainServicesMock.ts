// A mock service to simulate the Gateway and the Runner.

import { randomBytes } from "crypto";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import { concatHex, Log, parseAbiItem, PrivateKeyAccount, toHex, WatchEventReturnType } from "viem";

const eventsToWatch = [
    "event Add(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
    "event Sub(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
].map((e) => parseAbiItem(e));

export class OffChainServices {
    private teeComputeManagerAddress: `0x${string}`;
    private gateway: PrivateKeyAccount;
    private chainId: number;
    private handleToValueMap: Map<`0x${string}`, number> = new Map();
    private running = false;
    private stopGatewayService: WatchEventReturnType = () => {};

    constructor(teeComputeManagerAddress: `0x${string}`, gateway: PrivateKeyAccount, chainId: number) {
        this.teeComputeManagerAddress = teeComputeManagerAddress;
        this.gateway = gateway;
        this.chainId = chainId;
    }

    /**
     * Starts all mock off-chain services.
     */
    async start() {
        if (this.running) {
            throw new Error("Mock services are already running");
        }
        this.running = true;
        this.stopGatewayService = await this._startGateway();
    }

    /**
     * Stops all mock off-chain services.
     */
    async stop() {
        if (!this.running) {
            throw new Error("Mock services are not running");
        }
        this.running = false;
        this.stopGatewayService();
    }

    /**
     * Generates a handle and its corresponding proof for a given value.
     * It saves the value associated with the handle in an internal map.
     */
    async createHandleAndProof(
        value: number,
        teeType: number,
        userAddress: `0x${string}`,
        appAddress: `0x${string}`,
    ): Promise<{ handle: `0x${string}`; proof: `0x${string}` }> {
        const createdAt = BigInt(Math.floor(Date.now() / 1000)); // in seconds
        const handle = this.createHandle(value, teeType);
        const domain = {
            name: "TEEComputeManager",
            version: "1",
            chainId: this.chainId,
            verifyingContract: this.teeComputeManagerAddress,
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
        const signature = await this.gateway.signTypedData({
            domain,
            types,
            primaryType: "HandleProof",
            message,
        });
        const proof = concatHex([userAddress, appAddress, toHex(createdAt, { size: 32 }), signature]);
        return { handle, proof };
    }

    /**
     * Generates a handle for a given value.
     */
    createHandle(value: number, teeType: number): `0x${string}` {
        const preHandle = toHex(randomBytes(26));
        const chainIdBytes = toHex(this.chainId, { size: 4 });
        const teeTypeByte = toHex(teeType, { size: 1 });
        const versionByte = toHex(0, { size: 1 });
        const handle = concatHex([preHandle, chainIdBytes, teeTypeByte, versionByte]);
        this.handleToValueMap.set(handle, value);
        return handle;
    }

    async _startGateway() {
        console.log("📡 Gateway service mock started");
        const client = await connection.viem.getPublicClient();
        const unwatch = client.watchEvent({
            address: this.teeComputeManagerAddress,
            events: eventsToWatch,
            onLogs: (logs) => this._processEvent(logs),
            onError(error) {
                console.error("❌ Event listener error", error);
            },
        });
        return unwatch;
    }

    _processEvent(logs: Log[]) {
        for (const log of logs) {
            // this._processEvent(log);
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
    }
}
