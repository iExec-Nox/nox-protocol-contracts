// Turn On Iexec Vpn

/**
 * Standalone demo: encrypt two uint256 values, validate their proofs via ProofValidator,
 * then trigger an on-chain addition.
 *
 * Run with:
 *   npx tsx demo-proof-validator.ts
 */

import { createWalletClient, createPublicClient, http, parseAbi, decodeEventLog } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { arbitrumSepolia } from "viem/chains";
import { createViemHandleClient } from "../nox-handle-sdk/dist/esm/index.js";

// ── Config ───────────────────────────────────────────────────────────────────

const PRIVATE_KEY = "0x89caf0dbb1c1b277986beb277bcd44ec6136416b9d0fdca6133746071a49a201" as `0x${string}`;
const RPC_URL = "https://virtual.arbitrum-sepolia.eu.rpc.tenderly.co/09e4c7a4-80dc-4625-abb8-bb6473818e44";

const PROOF_VALIDATOR = "0x032a4442cdfbf92f508496077132a087d764d22a" as const;
const NOX_COMPUTE = "0xd2856C55447FBb45c85a4C484796fe690981B069" as const;

// ── ABIs (inline) ─────────────────────────────────────

const PROOF_VALIDATOR_ABI = parseAbi([
    "function validateAndAllowEuint256(bytes32 handle, bytes calldata proof) external",
]);

const NOX_COMPUTE_ABI = parseAbi([
    "function add(bytes32 leftHandOperand, bytes32 rightHandOperand) external returns (bytes32 result)",
    "event Add(address indexed caller, bytes32 leftHandOperand, bytes32 rightHandOperand, bytes32 result)",
]);

// ── Clients ───────────────────────────────────────────────────────────────────

const account = privateKeyToAccount(PRIVATE_KEY);

const walletClient = createWalletClient({
    account,
    chain: arbitrumSepolia,
    transport: http(RPC_URL),
});

const publicClient = createPublicClient({
    chain: arbitrumSepolia,
    transport: http(RPC_URL),
});

// HandleClient wraps the gateway API + blockchain reads.
const handleClient = await createViemHandleClient(walletClient);

console.log(`Network : Arbitrum Sepolia (${arbitrumSepolia.id})`);
console.log(`Caller  : ${account.address}`);

// ── Step 1: encrypt two uint256 values ───────────────────────────────────────
// applicationContract = ProofValidator because the proof will encode it as the `app`.

console.log("\n[1/4] Encrypting inputs via gateway...");
const [{ handle: handle1, handleProof: proof1 }, { handle: handle2, handleProof: proof2 }] = await Promise.all([
    handleClient.encryptInput(100n, "uint256", PROOF_VALIDATOR),
    handleClient.encryptInput(200n, "uint256", PROOF_VALIDATOR),
]);

console.log(`  handle1 : ${handle1}`);
console.log(`  handle2 : ${handle2}`);

// ── Step 2: validateAndAllowEuint256 handle1 ─────────────────────────────────
// ProofValidator calls Nox.fromExternal (validates proof) then Nox.allow (permanent ACL).

console.log("\n[2/4] validateAndAllowEuint256 handle1...");
const tx1 = await walletClient.writeContract({
    address: PROOF_VALIDATOR,
    abi: PROOF_VALIDATOR_ABI,
    functionName: "validateAndAllowEuint256",
    args: [handle1, proof1],
});
await publicClient.waitForTransactionReceipt({ hash: tx1 });
console.log(`  ✓ permanent access granted for handle1 (tx: ${tx1})`);

// ── Step 3: validateAndAllowEuint256 handle2 ─────────────────────────────────

console.log("\n[3/4] validateAndAllowEuint256 handle2...");
const tx2 = await walletClient.writeContract({
    address: PROOF_VALIDATOR,
    abi: PROOF_VALIDATOR_ABI,
    functionName: "validateAndAllowEuint256",
    args: [handle2, proof2],
});
await publicClient.waitForTransactionReceipt({ hash: tx2 });
console.log(`  ✓ permanent access granted for handle2 (tx: ${tx2})`);

// ── Step 4: add ───────────────────────────────────────────────────────────────
// Caller has persistent ACL access to both handles, so NoxCompute.add accepts the call.

console.log("\n[4/4] Triggering add(handle1, handle2)...");
const addTx = await walletClient.writeContract({
    address: NOX_COMPUTE,
    abi: NOX_COMPUTE_ABI,
    functionName: "add",
    args: [handle1, handle2],
});
const addReceipt = await publicClient.waitForTransactionReceipt({ hash: addTx });
console.log(`  ✓ add triggered (tx: ${addTx})`);

// Decode the Add event to retrieve the result handle.
const addLog = addReceipt.logs.find((log) => log.address.toLowerCase() === NOX_COMPUTE.toLowerCase());
if (!addLog) throw new Error("Add event not found in receipt");
const { args } = decodeEventLog({ abi: NOX_COMPUTE_ABI, ...addLog });
console.log(`\nResult handle: ${(args as { result: string }).result}`);
console.log("Done. The TEE runner will compute the encrypted sum off-chain.");
