// A mock service to simulate the Gateway and the Runner.

import { randomBytes } from "crypto";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";
import { concatHex, parseAbiItem, PrivateKeyAccount, toHex, WatchEventReturnType } from "viem";
import { TEEType } from "./TEEType.ts";

const MAX_UINT256 = 2n ** 256n - 1n;
const eventsToWatch = [
    "event WrapPublicScalar(address indexed caller,bytes32 plaintext,uint8 toType,bytes32 result)",
    "event Add(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
    "event Sub(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
    "event Div(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
    "event Mul(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 result)",
    "event SafeAdd(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 success,bytes32 result)",
    "event SafeSub(address indexed caller,bytes32 leftHandOperand,bytes32 rightHandOperand,bytes32 success,bytes32 result)",
    "event Select(address indexed caller,bytes32 condition,bytes32 ifTrue,bytes32 ifFalse,bytes32 result)",
];
const client = await connection.viem.getPublicClient();

export class OffChainServices {
    // Can be used for manual debugging.
    private printLogs = false;
    private noxComputeAddress: `0x${string}`;
    private gateway: PrivateKeyAccount;
    private chainId: number;
    private running = false;
    private handleToValueMap!: Map<`0x${string}`, bigint>;
    private stopGatewayService!: WatchEventReturnType;

    constructor(noxComputeAddress: `0x${string}`, gateway: PrivateKeyAccount) {
        this.noxComputeAddress = noxComputeAddress;
        this.gateway = gateway;
        this.chainId = client.chain.id;
    }

    /**
     * Starts all mock off-chain services.
     */
    async start() {
        if (this.running) {
            throw new Error("Mock services are already running");
        }
        this.running = true;
        this.handleToValueMap = new Map(); // reset the map with every start
        this.stopGatewayService = await this._startGateway();
        this._log("Mock services started");
    }

    /**
     * Stops all mock off-chain services.
     */
    async stop() {
        if (!this.running) {
            return;
        }
        this.running = false;
        this.handleToValueMap.clear();
        this.stopGatewayService();
        this._log("Mock services stopped");
    }

    /**
     * Simulates the Gateway service.
     * Generates a handle random and its proof and stores the corresponding value
     * in an internal map.
     */
    async generateAndStoreHandle(
        value: bigint,
        teeType: TEEType,
        userAddress: `0x${string}`,
        appAddress: `0x${string}`,
    ): Promise<{ handle: `0x${string}`; proof: `0x${string}` }> {
        const { handle, proof } = await this.generateHandle(teeType, userAddress, appAddress);
        this._saveHandle(handle, value);
        return { handle, proof };
    }

    /**
     * Generates a random handle and its proof.
     */
    async generateHandle(
        teeType: TEEType,
        userAddress: `0x${string}`,
        appAddress: `0x${string}`,
    ): Promise<{ handle: `0x${string}`; proof: `0x${string}` }> {
        const preHandle = toHex(randomBytes(25));
        const chainIdBytes = toHex(this.chainId, { size: 4 });
        const teeTypeByte = toHex(teeType, { size: 1 });
        const attrsByte = toHex(0x01, { size: 1 }); // isUniqHandle=1
        const versionByte = toHex(0, { size: 1 });
        const handle = concatHex([preHandle, chainIdBytes, teeTypeByte, attrsByte, versionByte]);
        const createdAt = BigInt(Math.floor(Date.now() / 1000)); // in seconds
        const domain = {
            name: "NoxCompute",
            version: "1",
            chainId: this.chainId,
            verifyingContract: this.noxComputeAddress,
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
     * Waits for event processing to be done.
     * Should be called after each transaction that emits relevant events.
     * TODO enhance this.
     */
    async waitForEventProcessing() {
        await new Promise((resolve) => setTimeout(resolve, 100)); // 0.1 second
    }

    /**
     * Simulates decryption.
     */
    decrypt(handle: `0x${string}`): bigint {
        const value = this.handleToValueMap.get(handle);
        if (value === undefined) {
            throw new Error(`Handle not found: ${handle}`);
        }
        return value;
    }

    private _saveHandle(handle: `0x${string}`, value: bigint) {
        this.handleToValueMap.set(handle, value);
        this._log(`Saved handle: ${handle} -> ${value}`);
    }

    private async _startGateway() {
        const unwatch = client.watchEvent({
            address: this.noxComputeAddress,
            events: eventsToWatch.map((e) => parseAbiItem(e)),
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
        this._log(`Gateway processing ${eventLogs.length} event(s): ${eventLogs.map((e) => e.eventName).join(", ")}`);
        for (const log of eventLogs) {
            const eventName = log.eventName;
            this._log(`Processing event: ${eventName}`);
            if (eventName === "WrapPublicScalar") {
                this._processWrapPublicScalarEvent(log);
            } else if (eventName === "Add") {
                this._processAddEvent(log);
            } else if (eventName === "Sub") {
                this._processSubEvent(log);
            } else if (eventName === "Div") {
                this._processDivEvent(log);
            } else if (eventName === "Mul") {
                this._processMulEvent(log);
            } else if (eventName === "SafeAdd") {
                this._processSafeAddEvent(log);
            } else if (eventName === "SafeSub") {
                this._processSafeSubEvent(log);
            } else if (eventName === "Select") {
                this._processSelectEvent(log);
            } else {
                throw new Error(`Unknown event: ${eventName}`);
            }
        }
    }

    private _processWrapPublicScalarEvent(log: any) {
        const { plaintext, result } = log.args as { plaintext: `0x${string}`; result: `0x${string}` };
        this._log(`(e) WrapPublicScalar: ${result} -> ${plaintext}`);
        this._saveHandle(result, BigInt(plaintext));
    }

    private _processAddEvent(log: any) {
        const { leftHandOperand, rightHandOperand, result } = log.args as {
            leftHandOperand: `0x${string}`;
            rightHandOperand: `0x${string}`;
            result: `0x${string}`;
        };
        const lhoValue = this.decrypt(leftHandOperand);
        const rhoValue = this.decrypt(rightHandOperand);
        const addResult = lhoValue + rhoValue;
        this._log(`(e) Add: ${result} -> ${lhoValue} + ${rhoValue} = ${addResult}`);
        this._saveHandle(result, addResult);
    }

    private _processSubEvent(log: any) {
        const { leftHandOperand, rightHandOperand, result } = log.args as {
            leftHandOperand: `0x${string}`;
            rightHandOperand: `0x${string}`;
            result: `0x${string}`;
        };
        const lhoValue = this.decrypt(leftHandOperand);
        const rhoValue = this.decrypt(rightHandOperand);
        const subResult = lhoValue - rhoValue;
        this._log(`(e) Sub: ${result} -> ${lhoValue} - ${rhoValue} = ${subResult}`);
        this._saveHandle(result, subResult);
    }

    private _processDivEvent(log: any) {
        const { leftHandOperand, rightHandOperand, result } = log.args as {
            leftHandOperand: `0x${string}`;
            rightHandOperand: `0x${string}`;
            result: `0x${string}`;
        };
        const lhoValue = this.decrypt(leftHandOperand);
        const rhoValue = this.decrypt(rightHandOperand);
        const divResult = lhoValue / rhoValue;
        this._log(`(e) Div: ${result} -> ${lhoValue} / ${rhoValue} = ${divResult}`);
        this._saveHandle(result, divResult);
    }

    private _processMulEvent(log: any) {
        const { leftHandOperand, rightHandOperand, result } = log.args as {
            leftHandOperand: `0x${string}`;
            rightHandOperand: `0x${string}`;
            result: `0x${string}`;
        };
        const lhoValue = this.decrypt(leftHandOperand);
        const rhoValue = this.decrypt(rightHandOperand);
        const mulResult = lhoValue * rhoValue;
        this._log(`(e) Mul: ${result} -> ${lhoValue} * ${rhoValue} = ${mulResult}`);
        this._saveHandle(result, mulResult);
    }

    // TODO add integration tests for overflow in SafeAdd and SafeSub.
    private _processSafeAddEvent(log: any) {
        const { leftHandOperand, rightHandOperand, success, result } = log.args as {
            leftHandOperand: `0x${string}`;
            rightHandOperand: `0x${string}`;
            success: `0x${string}`;
            result: `0x${string}`;
        };
        const lhoValue = this.decrypt(leftHandOperand);
        const rhoValue = this.decrypt(rightHandOperand);
        const addResult = lhoValue + rhoValue;
        if (addResult <= MAX_UINT256) {
            this._log(`(e) SafeAdd: ${result} -> ${lhoValue} + ${rhoValue} = ${addResult}`);
            this._saveHandle(success, 1n); // Save success handle as true.
            this._saveHandle(result, addResult); // Save result handle.
        } else {
            // overflow
            this._log(`SafeAdd overflow: ${result}`);
            this._saveHandle(success, 0n); // Save only success handle as false.
        }
    }

    private _processSafeSubEvent(log: any) {
        const { leftHandOperand, rightHandOperand, success, result } = log.args as {
            leftHandOperand: `0x${string}`;
            rightHandOperand: `0x${string}`;
            success: `0x${string}`;
            result: `0x${string}`;
        };
        const lhoValue = this.decrypt(leftHandOperand);
        const rhoValue = this.decrypt(rightHandOperand);
        const subResult = lhoValue - rhoValue;
        if (subResult >= 0n) {
            this._log(`(e) SafeSub: ${result} -> ${lhoValue} - ${rhoValue} = ${subResult}`);
            this._saveHandle(success, 1n); // Save success handle as true.
            this._saveHandle(result, subResult); // Save result handle.
        } else {
            // underflow
            this._log(`SafeSub underflow: ${result}`);
            this._saveHandle(success, 0n); // Save only success handle as false.
        }
    }

    private _processSelectEvent(log: any) {
        const { condition, ifTrue, ifFalse, result } = log.args as {
            condition: `0x${string}`;
            ifTrue: `0x${string}`;
            ifFalse: `0x${string}`;
            result: `0x${string}`;
        };
        const conditionValue = this.decrypt(condition);
        const ifTrueValue = this.decrypt(ifTrue);
        const ifFalseValue = this.decrypt(ifFalse);
        const selectResult = conditionValue !== 0n ? ifTrueValue : ifFalseValue;
        this._log(
            `(e) Select: ${result} -> condition: ${conditionValue} ? ${ifTrueValue} : ${ifFalseValue} = ${selectResult}`,
        );
        this._saveHandle(result, selectResult);
    }

    private _log = this.printLogs ? console.log : () => {};
}
