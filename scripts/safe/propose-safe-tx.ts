import * as core from "@actions/core";
import SafeApiKit from "@safe-global/api-kit";
import Safe from "@safe-global/protocol-kit";
import { type MetaTransactionData, OperationType } from "@safe-global/types-kit";
import { createPublicClient, http, isAddress, isHex } from "viem";
import { privateKeyToAccount } from "viem/accounts";

// Script to propose a transaction to a Safe multisig (Gnosis Safe) from CI.
//
// It is used for the Ethereum mainnet upgrade flow, where the `UPGRADER_ROLE` is held by a
// Safe multisig: `scripts/upgrade.ts` (prepare mode) deploys the new implementation and builds
// the `upgradeToAndCall` calldata, then this script proposes that transaction to the Safe so the
// signers can approve and execute it. No transaction is executed on-chain here.
//
// This is a self-contained Node script (no Hardhat): it only needs an RPC endpoint and the Safe
// Transaction Service, so it is run directly with `node scripts/safe/propose-safe-tx.ts`.
//
// Note on the `@safe-global/*` imports below: those packages ship CommonJS-shaped type
// declarations for their ESM entry points. Under this project's `moduleResolution: node16`, the
// type-checker therefore resolves the default import to the module namespace and flags the class
// usages, while the Node ESM runtime correctly exposes the class as the default export. The two
// `@ts-expect-error` directives document exactly that (the script is run with `node`, which strips
// types and never type-checks; CI does not run `tsc` either).
//
// Configuration is provided through environment variables:
//   - RPC_URL                    RPC endpoint of the target network (required)
//   - SAFE_ADDRESS               Safe multisig address (required)
//   - TRANSACTION_TO             transaction target address, e.g. the proxy (required)
//   - TRANSACTION_DATA           transaction calldata (optional, defaults to "0x")
//   - TRANSACTION_VALUE          wei value to send (optional, defaults to "0")
//   - SAFE_PROPOSER_PRIVATE_KEY  private key of the proposer (a Safe owner) (required)
//   - SAFE_API_KEY               Safe Transaction Service API key (required)
//   - DRY_RUN                    when "true"/"1", validate and sign without proposing (optional)

interface ProposeConfig {
    rpcUrl: string;
    safeAddress: `0x${string}`;
    transactionTo: `0x${string}`;
    transactionData: `0x${string}`;
    transactionValue: string;
    safeProposerPrivateKey: `0x${string}`;
    safeApiKey: string;
    dryRun: boolean;
}

/**
 * Reads and validates the configuration from environment variables.
 * Throws an aggregated error listing every invalid or missing variable.
 */
function readConfig(): ProposeConfig {
    const errors: string[] = [];
    const env = process.env;

    const rpcUrl = env.RPC_URL ?? "";
    if (!rpcUrl) {
        errors.push("RPC_URL is required");
    }

    const safeAddress = env.SAFE_ADDRESS ?? "";
    if (!isAddress(safeAddress)) {
        errors.push("SAFE_ADDRESS must be a valid address");
    }

    const transactionTo = env.TRANSACTION_TO ?? "";
    if (!isAddress(transactionTo)) {
        errors.push("TRANSACTION_TO must be a valid address");
    }

    const transactionData = env.TRANSACTION_DATA ?? "0x";
    if (!isHex(transactionData)) {
        errors.push("TRANSACTION_DATA must be valid hex data (0x-prefixed)");
    }

    const rawValue = env.TRANSACTION_VALUE ?? "0";
    let transactionValue = "0";
    try {
        if (BigInt(rawValue) < 0n) {
            errors.push("TRANSACTION_VALUE must be a non-negative integer");
        } else {
            transactionValue = BigInt(rawValue).toString();
        }
    } catch {
        errors.push("TRANSACTION_VALUE must be a non-negative integer");
    }

    const rawKey = env.SAFE_PROPOSER_PRIVATE_KEY ?? "";
    const normalizedKey = rawKey.startsWith("0x") ? rawKey : `0x${rawKey}`;
    if (!/^0x[0-9a-fA-F]{64}$/.test(normalizedKey)) {
        errors.push("SAFE_PROPOSER_PRIVATE_KEY must be a 32-byte hex private key");
    }

    const safeApiKey = env.SAFE_API_KEY ?? "";
    if (!safeApiKey) {
        errors.push("SAFE_API_KEY is required");
    }

    const dryRun = env.DRY_RUN === "true" || env.DRY_RUN === "1";

    if (errors.length > 0) {
        throw new Error(`Invalid configuration:\n  - ${errors.join("\n  - ")}`);
    }

    return {
        rpcUrl,
        safeAddress: safeAddress as `0x${string}`,
        transactionTo: transactionTo as `0x${string}`,
        transactionData: transactionData as `0x${string}`,
        transactionValue,
        safeProposerPrivateKey: normalizedKey as `0x${string}`,
        safeApiKey,
        dryRun,
    };
}

/**
 * Proposes (or, in dry-run mode, only validates and signs) a Safe multisig transaction.
 */
async function proposeSafeTransaction() {
    const config = readConfig();

    core.info(`🚀 Starting Safe transaction ${config.dryRun ? "validation (DRY RUN)" : "proposal"}...`);
    core.info(`📍 Safe address: ${config.safeAddress}`);
    core.info(`🎯 Target address: ${config.transactionTo}`);

    const account = privateKeyToAccount(config.safeProposerPrivateKey);
    core.info(`🔑 Proposer address: ${account.address}`);

    // Resolve the chain id from the RPC so the Safe Transaction Service is queried on the
    // correct network without hardcoding it.
    const publicClient = createPublicClient({ transport: http(config.rpcUrl) });
    const chainId = await publicClient.getChainId();
    core.info(`🌐 Chain id: ${chainId}`);

    // @ts-expect-error @safe-global ships CommonJS-shaped types; the Node ESM runtime default is the class (see header note).
    const apiKit = new SafeApiKit({
        chainId: BigInt(chainId),
        apiKey: config.safeApiKey,
    });

    // @ts-expect-error @safe-global ships CommonJS-shaped types; the Node ESM runtime default is the class (see header note).
    const protocolKit = await Safe.init({
        provider: config.rpcUrl,
        signer: config.safeProposerPrivateKey,
        safeAddress: config.safeAddress,
    });
    core.info(`👤 Safe initialized for: ${config.safeAddress}`);

    const safeTransactionData: MetaTransactionData = {
        to: config.transactionTo,
        value: config.transactionValue,
        data: config.transactionData,
        operation: OperationType.Call,
    };

    core.info("📝 Creating Safe transaction...");
    const safeTransaction = await protocolKit.createTransaction({ transactions: [safeTransactionData] });
    const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
    const signature = await protocolKit.signHash(safeTxHash);
    core.info(`🔐 Transaction signed - hash: ${safeTxHash}`);

    core.setOutput("tx-hash", safeTxHash);

    if (config.dryRun) {
        core.info("🧪 DRY RUN MODE - transaction validated and signed but not proposed");
        core.info("📋 Transaction preview:");
        core.info(`   To: ${safeTransactionData.to}`);
        core.info(`   Value: ${safeTransactionData.value}`);
        core.info(`   Data: ${safeTransactionData.data}`);
        core.info(`   Operation: ${safeTransactionData.operation}`);
        core.setOutput(
            "tx-details",
            JSON.stringify({
                to: safeTransactionData.to,
                value: safeTransactionData.value,
                data: safeTransactionData.data,
                operation: safeTransactionData.operation,
                safeTxHash,
                senderAddress: account.address,
                dryRun: true,
            }),
        );
        core.info(`✅ Transaction validated successfully (not proposed)`);
        core.info(`🔗 Transaction hash (would be): ${safeTxHash}`);
        return;
    }

    await apiKit.proposeTransaction({
        safeAddress: config.safeAddress,
        safeTransactionData: safeTransaction.data,
        safeTxHash,
        senderAddress: account.address,
        senderSignature: signature.data,
        origin: "GitHub Action - Propose Safe Multisig Transaction",
    });

    const transaction = await apiKit.getTransaction(safeTxHash);
    core.setOutput("tx-details", JSON.stringify(transaction));

    core.info(`✅ Transaction proposed successfully!`);
    core.info(`🔗 Transaction hash: ${safeTxHash}`);
    core.info(`⏳ Waiting for other owners to sign and execute...`);
}

proposeSafeTransaction().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : "Unknown error";
    core.setFailed(`❌ Error proposing Safe transaction: ${message}`);
    if (error instanceof Error && error.stack) {
        core.error(error.stack);
    }
    process.exitCode = 1;
});
