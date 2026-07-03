#!/usr/bin/env bash

# Usage: bash scripts/upgrade/upgrade.sh --some-option some-value --network <network-name>

# Arbitrum Sepolia and its Tenderly fork (tenderlyArbitrumSepolia) share the same chain id,
# so their OZ manifests would collide in the default .openzeppelin/ directory. To avoid this,
# the Tenderly fork uses a dedicated manifest directory; all other networks use the default .openzeppelin/ directory.

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

# Use a dedicated .openzeppelin manifest directory only for the Tenderly fork.
# For all other networks, the default .openzeppelin manifest directory will be used.
if [[ "$network_name" == "tenderlyArbitrumSepolia" ]]; then
    export MANIFEST_DEFAULT_DIR="./.openzeppelin/${network_name}"
fi

pnpm hardhat run scripts/upgrade/upgrade.ts "${args[@]}"
