#!/usr/bin/env node
// Inject a sepolia entry into the genesis (v0.1.0) source so that:
//   - Hardhat accepts `--network sepolia`
//   - `scripts/deploy.ts` finds a matching `chainConfig`
// The injected `initialOwner` matches the value used at the original arbitrumSepolia
// deploy, which is required for the CREATE2 proxy address to be identical.
//
// Usage (run from the repo root after `git checkout v0.1.0`):
//   node scripts/patch-genesis-sepolia.mjs

import { readFileSync, writeFileSync } from "node:fs";

const HARDHAT_CONFIG = "hardhat.config.ts";
const CHAIN_CONFIG = "config/config.ts";

// Initial owner used at the original arbitrumSepolia v0.1.0 deploy.
const INITIAL_OWNER = "0x0bcEAC5cdb4f6390c470972dCBDbeefdD88cfB8f";

const sepoliaNetwork = `
        sepolia: {
            type: "http",
            chainType: "l1",
            chainId: 11155111,
            url: configVariable("RPC_URL"),
            accounts: [configVariable("PRIVATE_KEY")],
        },`;

const sepoliaChainConfig = `
    sepolia: {
        chainId: 11155111,
        initialOwner: "${INITIAL_OWNER}",
        kmsPublicKey: undefined,
    },`;

function patch(file, snippet) {
    const src = readFileSync(file, "utf8");
    const out = src.replace(/(tenderlyArbitrumSepolia: \{[\s\S]*?\},)/, `$1${snippet}`);
    if (out === src) {
        throw new Error(`Failed to patch ${file}: tenderlyArbitrumSepolia block not found.`);
    }
    writeFileSync(file, out);
    console.log(`Patched ${file}`);
}

patch(HARDHAT_CONFIG, sepoliaNetwork);
patch(CHAIN_CONFIG, sepoliaChainConfig);
console.log("Genesis source ready for sepolia deploy.");
