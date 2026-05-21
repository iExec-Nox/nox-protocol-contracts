#!/usr/bin/env bash

#
# Usage: bash scripts/fix-local-address.sh
#
# The NoxCompute proxy address for local dev (chainId 31337) is hardcoded in
# contracts/sdk/Nox.sol. Because the address is derived from the contract
# bytecode via CREATE2, it changes whenever the bytecode changes.
# Run this script to redeploy locally and patch Nox.sol with the new address.

set -euo pipefail

NOX_SOL="contracts/sdk/Nox.sol"

# Extract old address before deploying
OLD_ADDRESS=$(sed -n '/block.chainid == 31337/{n;s/.*return \(0x[0-9a-fA-F]\{40\}\).*/\1/p;}' "$NOX_SOL")
echo "Old proxy address: $OLD_ADDRESS"

# Deploy to local network and print output at failure.
DEPLOY_OUTPUT=$(pnpm run deploy 2>&1) || { echo "$DEPLOY_OUTPUT" >&2; exit 1; }
# Extract address from line: "NoxCompute#proxy - 0xAbCd..."
NEW_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'NoxCompute#proxy\s*-\s*\K0x[0-9a-fA-F]{40}')
echo "New proxy address: $NEW_ADDRESS"

if [ -z "$NEW_ADDRESS" ]; then
    echo "Error: could not extract proxy address from deploy output" >&2
    echo "Deploy output:" >&2
    echo "$DEPLOY_OUTPUT" >&2
    exit 1
fi

# Replace the exact 42-char address (0x + 40 hex) on the line following the 31337 chainId check
sed -i "/block.chainid == 31337/{n;s/return 0x[0-9a-fA-F]\{40\}/return $NEW_ADDRESS/;}" "$NOX_SOL"

echo "Updated $NOX_SOL"
