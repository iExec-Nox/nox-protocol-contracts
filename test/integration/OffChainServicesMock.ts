// A mock service to simulate the Gateway and the Runner.

import { randomBytes } from "crypto";
import connection from "../../scripts/utils/hardhat-connection-singleton.js";
import { concatHex, parseAbiItem, PrivateKeyAccount, toHex, WatchEventReturnType } from "viem";

// Can be used for debugging.
const printLogs = true;

const eventsToWatch = [
    "event PlaintextToEncrypted(address indexed caller,uint256 plainText,uint8 toType,bytes32 result)",
    "event Add(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
    "event Sub(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
].map((e) => parseAbiItem(e));

export class OffChainServices {
    private teeComputeManagerAddress: `0x${string}`;
    private gateway: PrivateKeyAccount;
    private chainId: number;
    private handleToValueMap: Map<`0x${string}`, bigint> = new Map();
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
        _print("Mock services started");
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
        _print("Mock services stopped");
    }

    /**
     * Simulates the Gateway service.
     * Generates a handle and its corresponding proof for a given value.
     * It saves the value associated with the handle in an internal map.
     */
    async createHandleAndProof(
        value: bigint,
        teeType: number,
        userAddress: `0x${string}`,
        appAddress: `0x${string}`,
    ): Promise<{ handle: `0x${string}`; proof: `0x${string}` }> {
        const createdAt = BigInt(Math.floor(Date.now() / 1000)); // in seconds
        const handle = this._createAndSaveHandle(value, teeType);
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

    // Wait a bit to ensure event processing is done.
    /**
     * Waits for event processing to be done.
     * TODO enhance this.
     */
    async waitForEventProcessing() {
        await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    /**
     * Simulates decryption.
     */
    decrypt(handle: `0x${string}`): bigint {
        const value = this.handleToValueMap.get(handle);
        if (!value) {
            throw new Error(`Handle not found: ${handle}`);
        }
        return value;
    }

    /**
     * Generates a handle for a given value and saves it in the internal map.
     */
    private _createAndSaveHandle(value: bigint, teeType: number): `0x${string}` {
        const preHandle = toHex(randomBytes(26));
        const chainIdBytes = toHex(this.chainId, { size: 4 });
        const teeTypeByte = toHex(teeType, { size: 1 });
        const versionByte = toHex(0, { size: 1 });
        const handle = concatHex([preHandle, chainIdBytes, teeTypeByte, versionByte]);
        this._saveHandle(handle, value);
        return handle;
    }

    private async _startGateway() {
        const client = await connection.viem.getPublicClient();
        const unwatch = client.watchEvent({
            address: this.teeComputeManagerAddress,
            events: eventsToWatch,
            // pollingInterval: 10,
            onLogs: (logs) => this._processEvents(logs),
            onError(error) {
                console.error("❌ Event listener error");
                console.error(error);
            },
        });
        return unwatch;
    }

    /**
     * Simulates the off-chain runner.
     */
    private _processEvents(eventLogs: any[]) {
        _print(`Gateway processing ${eventLogs.length} event(s): ${eventLogs.map((e) => e.eventName).join(", ")}`);
        for (const log of eventLogs) {
            const eventName = log.eventName;
            _print(`Processing event: ${eventName}`);
            if (eventName === "PlaintextToEncrypted") {
                const { plainText, result } = log.args as { plainText: bigint; result: `0x${string}` };
                _print(`(e) PlaintextToEncrypted: ${result} -> ${plainText}`);
                this._saveHandle(result, plainText);
            } else if (eventName === "Add") {
                const { leftHandOperand, rightHandOperand, result } = log.args as {
                    leftHandOperand: bigint;
                    rightHandOperand: bigint;
                    result: `0x${string}`;
                };
                const addValue = leftHandOperand + rightHandOperand;
                _print(`(e) Add: ${leftHandOperand} + ${rightHandOperand} = ${addValue} -> ${result}`);
                this._saveHandle(result, addValue);
            } else if (eventName === "Sub") {
                const { leftHandOperand, rightHandOperand, result } = log.args as {
                    leftHandOperand: bigint;
                    rightHandOperand: bigint;
                    result: `0x${string}`;
                };
                const subValue = leftHandOperand - rightHandOperand;
                _print(`(e) Sub: ${leftHandOperand} - ${rightHandOperand} = ${subValue} -> ${result}`);
                this._saveHandle(result, subValue);
            } else {
                throw new Error(`Unknown event: ${eventName}`);
            }
        }
    }

    private _saveHandle(handle: `0x${string}`, value: bigint) {
        this.handleToValueMap.set(handle, value);
        _print(`Saved handle: ${handle} -> value: ${value}`);
    }
}

function _print(message: string) {
    if (printLogs) {
        console.log(`[Debug] ${message}`);
    }
}
