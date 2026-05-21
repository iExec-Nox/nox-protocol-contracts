#!/usr/bin/env sh

#
# Usage: sh scripts/fix-local-address.sh
#
# The NoxCompute proxy address for local dev (chainId 31337) is hardcoded in
# contracts/sdk/Nox.sol. Because the address is derived from the contract
# bytecode via CREATE2, it changes whenever the bytecode changes.
# Run this script to redeploy locally and patch Nox.sol with the new address.

set -eu

NOX_SOL="contracts/sdk/Nox.sol"

echo "Updating local proxy address in $NOX_SOL"
# Extract old address before deploying
OLD_ADDRESS=$(sed -n '/block.chainid == 31337/{n;s/.*return \(0x[0-9a-fA-F]\{40\}\).*/\1/p;}' "$NOX_SOL")
echo "Old proxy address: $OLD_ADDRESS"

# Deploy to local network and print output at failure.
DEPLOY_OUTPUT=$(pnpm run deploy 2>&1) || { echo "$DEPLOY_OUTPUT" >&2; exit 1; }
# Extract address from line: "NoxCompute#proxy - 0xAbCd..."
NEW_ADDRESS=$(echo "$DEPLOY_OUTPUT" | sed -n 's/.*NoxCompute#proxy[[:space:]]*-[[:space:]]*\(0x[0-9a-fA-F]\{40\}\).*/\1/p')
echo "New proxy address: $NEW_ADDRESS"

if [ -z "$NEW_ADDRESS" ]; then
    echo "Error: could not extract proxy address from deploy output" >&2
    echo "Deploy output:" >&2
    echo "$DEPLOY_OUTPUT" >&2
    exit 1
fi

# Check if Nox.sol is clean before applying the replacement
git diff --quiet "$NOX_SOL" && git diff --cached --quiet && CAN_AUTO_COMMIT=true || CAN_AUTO_COMMIT=false

# Replace the exact 42-char address (0x + 40 hex) on the line following the 31337 chainId check
sed -i "/block.chainid == 31337/{n;s/return 0x[0-9a-fA-F]\{40\}/return $NEW_ADDRESS/;}" "$NOX_SOL"


# Don't commit if there are other changes.
if ! $CAN_AUTO_COMMIT; then
    echo "Warning: $NOX_SOL has other changes — skipping auto-commit"
# If the only change is the address update, commit it.
elif ! git diff --quiet "$NOX_SOL"; then
    echo "Updated $NOX_SOL"
    git add "$NOX_SOL"
    git commit -m "chore: update local proxy address"
    echo "Committed $NOX_SOL"
fi
