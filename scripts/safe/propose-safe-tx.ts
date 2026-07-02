import * as core from "@actions/core";
import SafeApiKit from "@safe-global/api-kit";
import Safe from "@safe-global/protocol-kit";
import { type MetaTransactionData, OperationType } from "@safe-global/types-kit";
import { createPublicClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { env } from "./env.ts";

/**
 * Proposes (or, in dry-run mode, only validates and signs) a Safe multisig transaction.
 */
async function proposeSafeTransaction() {
    const {
        RPC_URL: rpcUrl,
        SAFE_ADDRESS: safeAddress,
        TRANSACTION_TO: transactionTo,
        TRANSACTION_VALUE: transactionValue,
        TRANSACTION_DATA: transactionData,
        SAFE_PROPOSER_PRIVATE_KEY: safeProposerPrivateKey,
        SAFE_API_KEY: safeApiKey,
        DRY_RUN: dryRun,
    } = env;

    core.info(`🚀 Starting Safe transaction ${dryRun ? "validation (DRY RUN)" : "proposal"}...`);
    core.info(`📍 Safe address: ${safeAddress}`);
    core.info(`🎯 Target address: ${transactionTo}`);

    const account = privateKeyToAccount(safeProposerPrivateKey as `0x${string}`);
    core.info(`🔑 Proposer address: ${account.address}`);

    // Resolve the chain id from the RPC so the Safe Transaction Service is queried on the
    // correct network without hardcoding it.
    const publicClient = createPublicClient({ transport: http(rpcUrl) });
    const chainId = await publicClient.getChainId();
    core.info(`🌐 Chain id: ${chainId}`);

    // @ts-expect-error @safe-global ships CommonJS-shaped types; the Node ESM runtime default is the class (see header note).
    const apiKit = new SafeApiKit({
        chainId: BigInt(chainId),
        apiKey: safeApiKey,
    });

    // @ts-expect-error @safe-global ships CommonJS-shaped types; the Node ESM runtime default is the class (see header note).
    const protocolKit = await Safe.init({
        provider: rpcUrl,
        signer: safeProposerPrivateKey,
        safeAddress,
    });
    core.info(`👤 Safe initialized for: ${safeAddress}`);

    const safeTransactionData: MetaTransactionData = {
        to: transactionTo,
        value: transactionValue,
        data: transactionData,
        operation: OperationType.Call,
    };

    core.info("📝 Creating Safe transaction...");
    const safeTransaction = await protocolKit.createTransaction({ transactions: [safeTransactionData] });
    const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);
    const signature = await protocolKit.signHash(safeTxHash);
    core.info(`🔐 Transaction signed - hash: ${safeTxHash}`);

    core.setOutput("tx-hash", safeTxHash);

    if (dryRun) {
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
        safeAddress,
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
