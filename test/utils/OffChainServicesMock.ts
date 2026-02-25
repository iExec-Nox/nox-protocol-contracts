import connection from "../../scripts/utils/hardhat-connection-singleton.ts";
import { createWalletClient, http } from "viem";
import type { Account } from "viem";
import { createViemHandleClient } from "@iexec-nox/handle";

/**
 * Off-chain services integration.
 *
 * Assumes docker-compose.test.yml is already running (start with `pnpm services:up`).
 * This class only handles contract setup and communication with the services.
 */
export class OffChainServices {
    private noxComputeAddress: `0x${string}`;
    private readonly rpcUrl = "http://localhost:8545";
    private readonly gatewayUrl = "http://localhost:9203";

    // Fixed test keys — see test/fixtures/keys/ for the corresponding key files.
    private static readonly gatewayAddress = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf" as `0x${string}`;
    private static readonly kmsSigner = "0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF" as `0x${string}`;
    private static readonly kmsEcPublicKey =
        "0x0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798" as `0x${string}`;

    constructor(noxComputeAddress: `0x${string}`, _gateway?: unknown) {
        this.noxComputeAddress = noxComputeAddress;
    }

    /**
     * Registers the fixed test keys in the contract and waits for the gateway to be ready.
     */
    async start() {
        const noxCompute = await connection.viem.getContractAt("NoxCompute", this.noxComputeAddress);
        const publicClient = await connection.viem.getPublicClient();

        const gatewayTxHash = await noxCompute.write.setGateway([OffChainServices.gatewayAddress]);
        await publicClient.waitForTransactionReceipt({ hash: gatewayTxHash });

        const kmsTxHash = await noxCompute.write.setKmsPublicKey([OffChainServices.kmsEcPublicKey]);
        await publicClient.waitForTransactionReceipt({ hash: kmsTxHash });

        await _waitForHealthy(`${this.gatewayUrl}/health`);
    }

    /**
     * No-op — docker-compose lifecycle is managed externally via `pnpm services:up/down`.
     */
    async stop() {}

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
        const baseClient = createWalletClient({
            account,
            transport: http(this.rpcUrl),
        });
        // Override getAddresses() to return only this account's address.
        // The SDK's ViemBlockchainService.getAddress() calls getAddresses()[0], which on a
        // JSON-RPC transport calls eth_accounts and returns ALL Hardhat accounts — so [0] is
        // always admin. This ensures the correct account is used as the handle owner.
        const walletClient = baseClient.extend(() => ({
            async getAddresses(): Promise<[`0x${string}`, ...`0x${string}`[]]> {
                return [account.address as `0x${string}`];
            },
        }));
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
}

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
