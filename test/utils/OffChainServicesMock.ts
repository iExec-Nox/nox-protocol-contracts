import { spawn } from "child_process";
import { mkdirSync, writeFileSync, existsSync, rmSync } from "fs";
import { join } from "path";
import connection from "../../scripts/utils/hardhat-connection-singleton.ts";
import { createWalletClient, http } from "viem";
import type { Account } from "viem";
import { createViemHandleClient } from "@iexec-nox/handle";

/**
 * Real off-chain services integration using docker-compose.test.yml.
 *
 * Uses fixed test keys for the gateway and KMS, registers them in the contract,
 * and starts the full docker-compose stack.
 */
export class OffChainServices {
    private noxComputeAddress: `0x${string}`;
    private readonly rpcUrl = "http://localhost:8545";
    private readonly gatewayUrl = "http://localhost:9203";
    private readonly projectRoot = new URL("../../", import.meta.url).pathname;
    private readonly testDataDir = join(this.projectRoot, "test-data");
    private running = false;

    constructor(noxComputeAddress: `0x${string}`, _gateway?: unknown) {
        this.noxComputeAddress = noxComputeAddress;
    }

    /**
     * Starts the local off-chain services stack.
     *
     * Writes fixed test key files, registers the keys in the contract,
     * and starts the docker-compose stack.
     */
    async start() {
        if (this.running) {
            throw new Error("OffChainServices are already running");
        }
        this.running = true;

        mkdirSync(join(this.testDataDir, "kms"), { recursive: true });
        mkdirSync(join(this.testDataDir, "gateway"), { recursive: true });

        // --- Gateway signer key (fixed test key, registered in contract) ---
        writeFileSync(join(this.testDataDir, "gateway", "gateway_keystore.json"), _TEST_GATEWAY_KEYSTORE);
        const gatewayAddress = _TEST_GATEWAY_ADDRESS;

        // --- KMS ECIES key pair (fixed test key, registered in contract) ---
        writeFileSync(join(this.testDataDir, "kms", "kms.key"), _TEST_KMS_EC_KEY_FILE);
        const kmsPublicKeyHex = _TEST_KMS_EC_PUBLIC_KEY_HEX;

        // --- KMS signer key (fixed test key, address configured in gateway env) ---
        writeFileSync(join(this.testDataDir, "kms", "keystore_signer.json"), _TEST_KMS_SIGNER_KEYSTORE);
        const kmsSignerAddress = _TEST_KMS_SIGNER_ADDRESS;

        // --- Update contract ---
        const noxCompute = await connection.viem.getContractAt("NoxCompute", this.noxComputeAddress);
        const publicClient = await connection.viem.getPublicClient();
        const gatewayTxHash = await noxCompute.write.setGateway([gatewayAddress]);
        await publicClient.waitForTransactionReceipt({ hash: gatewayTxHash });
        const kmsTxHash = await noxCompute.write.setKmsPublicKey([kmsPublicKeyHex]);
        await publicClient.waitForTransactionReceipt({ hash: kmsTxHash });

        // Get current block to avoid re-processing old events in the ingestor.
        const currentBlock = await publicClient.getBlockNumber();

        // --- Start docker-compose ---
        const networkConfig = connection.networkConfig as { type?: string; url?: string; chainId?: number };
        const chainId = networkConfig.chainId ?? 31337;
        const dockerRpcUrl = "http://host.docker.internal:8545";

        await this._dockerComposeUp({
            NOX_COMPUTE_CONTRACT: this.noxComputeAddress,
            NOX_CHAIN_ID: String(chainId),
            NOX_RPC_URL: dockerRpcUrl,
            NOX_KMS_SIGNER_ADDRESS: kmsSignerAddress,
            NOX_GATEWAY_ADDRESS: gatewayAddress,
            NOX_INITIAL_BLOCK: String(currentBlock),
        });

        // Wait for the gateway HTTP API to be ready.
        await _waitForHealthy(`${this.gatewayUrl}/health`);
    }

    /**
     * Stops all off-chain services and cleans up.
     */
    async stop() {
        if (!this.running) {
            return;
        }
        this.running = false;
        await this._dockerComposeDown();
        if (existsSync(this.testDataDir)) {
            rmSync(this.testDataDir, { recursive: true, force: true });
        }
    }

    /**
     * Waits for blockchain events to be processed by the off-chain pipeline.
     */
    async waitForEventProcessing() {
        // Allow time for:
        //   - Ingestor to poll the chain (200ms poll delay)
        //   - Runner to process and post results to the gateway
        await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    /**
     * Creates an SDK client for the given account to interact with the gateway.
     * Can be used to encrypt inputs and decrypt handles.
     * Must be called after start().
     */
    async createClient(account: Account) {
        const walletClient = createWalletClient({
            account,
            transport: http(this.rpcUrl),
        });
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        return createViemHandleClient(walletClient as any, {
            gatewayUrl: this.gatewayUrl,
            smartContractAddress: this.noxComputeAddress,
        });
    }

    /**
     * Decrypts a handle by requesting the plaintext from the gateway.
     * The signer must be an authorized viewer of the handle in the ACL.
     */
    async decrypt(handle: `0x${string}`, signer: Account): Promise<bigint> {
        const client = await this.createClient(signer);
        const { value } = await client.decrypt(handle);
        return value as bigint;
    }

    private _dockerComposeUp(env: Record<string, string>): Promise<void> {
        return new Promise((resolve, reject) => {
            const proc = spawn("docker", ["compose", "-f", "docker-compose.test.yml", "up", "-d"], {
                cwd: this.projectRoot,
                env: { ...process.env, ...env },
                stdio: "inherit",
            });
            proc.on("close", (code) => {
                if (code === 0) resolve();
                else reject(new Error(`docker compose up failed with exit code ${code}`));
            });
            proc.on("error", reject);
        });
    }

    private _dockerComposeDown(): Promise<void> {
        return new Promise((resolve) => {
            const proc = spawn("docker", ["compose", "-f", "docker-compose.test.yml", "down", "-v"], {
                cwd: this.projectRoot,
                env: process.env,
                stdio: "inherit",
            });
            proc.on("close", () => resolve());
            proc.on("error", (err) => {
                console.error("docker compose down error:", err);
                resolve();
            });
        });
    }
}

// ============ Fixed test keys ============
//
// All keys use private key 1 (gateway), 2 (KMS signer), and the secp256k1
// generator point G (KMS EC pair). Keystores are pre-encrypted with empty
// password, zero salt, and zero IV using scrypt N=8192 — for tests only.

const _TEST_GATEWAY_ADDRESS = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf" as `0x${string}`;
const _TEST_GATEWAY_KEYSTORE =
    '{"version":3,"address":"7e5f4552091a69125d5dfcb7b8c2659029395bdf","crypto":{"ciphertext":"79e81056502c919d0db62b27df639fc81e79da44bcaadd300fbcd6375f318b57","cipherparams":{"iv":"00000000000000000000000000000000"},"cipher":"aes-128-ctr","kdf":"scrypt","kdfparams":{"dklen":32,"salt":"0000000000000000000000000000000000000000000000000000000000000000","n":8192,"r":8,"p":1},"mac":"e651f3fe381006f112bb3c826a4dff5ef369ac74732ab80124a693abcf1fa170"}}';

const _TEST_KMS_SIGNER_ADDRESS = "0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF" as `0x${string}`;
const _TEST_KMS_SIGNER_KEYSTORE =
    '{"version":3,"address":"2b5ad5c4795c026514f8317c7a215e218dccd6cf","crypto":{"ciphertext":"79e81056502c919d0db62b27df639fc81e79da44bcaadd300fbcd6375f318b54","cipherparams":{"iv":"00000000000000000000000000000000"},"cipher":"aes-128-ctr","kdf":"scrypt","kdfparams":{"dklen":32,"salt":"0000000000000000000000000000000000000000000000000000000000000000","n":8192,"r":8,"p":1},"mac":"b2e45d4fa368776e9c63d9a84e14ca20149a2409318cb72ca635c97ae9a45d3d"}}';

// secp256k1 generator point G: private key = 1, compressed public key = 02 + x.
const _TEST_KMS_EC_PUBLIC_KEY_HEX =
    "0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798" as `0x${string}`;
const _TEST_KMS_EC_KEY_FILE = Buffer.concat([
    Buffer.from("0000000000000000000000000000000000000000000000000000000000000001", "hex"),
    Buffer.from(_TEST_KMS_EC_PUBLIC_KEY_HEX.slice(2), "hex"),
]);

/**
 * Polls a health endpoint until it returns 200, or throws after maxWaitMs.
 */
async function _waitForHealthy(url: string, maxWaitMs = 60_000): Promise<void> {
    const deadline = Date.now() + maxWaitMs;
    while (Date.now() < deadline) {
        try {
            const res = await fetch(url);
            if (res.ok) return;
        } catch {
            // Service not yet up
        }
        await new Promise((resolve) => setTimeout(resolve, 500));
    }
    throw new Error(`Service at ${url} did not become healthy within ${maxWaitMs}ms`);
}
