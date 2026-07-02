#!/usr/bin/env bash

# Usage: bash scripts/upgrade/upgrade.sh --some-option some-value --network <network-name>

# This is a fix to use different .openzeppelin manifest files for Arbitrum Sepolia and
# its forks (tenderlyArbitrumSepolia) as they both have the same chain id. Without
# this fix, they both would conflict and use the same file .openzeppelin/arbitrumSepolia.json.

set -euo pipefail

if [[ "$#" -lt 2 ]]; then
    echo "Usage: bash scripts/upgrade/upgrade.sh --some-option some-value --network <network-name>"
    exit 1
fi

args=("$@")
network_name=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --network)
            if [[ "$#" -lt 2 ]]; then
                echo "Error: --network requires a value"
                exit 1
            fi
            network_name="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$network_name" ]]; then
    echo "Error: missing required --network <network-name> argument"
    exit 1
fi

# Use a different .openzeppelin manifest directory for Arbitrum Sepolia and its Tenderly fork.
# For other networks, the default .openzeppelin manifest directory will be used.
if [[ "$network_name" == "arbitrumSepolia" || "$network_name" == "tenderlyArbitrumSepolia" ]]; then
    export MANIFEST_DEFAULT_DIR="./.openzeppelin/${network_name}"
fi

pnpm hardhat run scripts/upgrade/upgrade.ts "${args[@]}"
