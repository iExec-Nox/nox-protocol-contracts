# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
pnpm run build          # Compile contracts
pnpm run test           # Run all tests (unit + integration)
pnpm run test:gas       # Run tests with gas reports
pnpm run coverage       # Generate coverage report
pnpm run lint           # Lint + fix (ESLint + solhint)
pnpm run lint:check     # Lint check only
pnpm run format         # Format with Prettier
pnpm run format:check   # Check formatting
pnpm run clean          # Remove build artifacts
```

**Run a single test file:**

```bash
pnpm hardhat test test/unit/NoxCompute.t.sol
pnpm hardhat test test/integration/NoxComputeIT.test.ts
```

**Deploy:**

```bash
pnpm run deploy                  # Deploy to local EDR (default network)
pnpm run deploy:production       # Deploy with optimizer + viaIR (for real networks)
```

**Upgrade:**

```bash
pnpm run upgrade                 # Upgrade proxy on default network
pnpm run upgrade:production      # Upgrade with optimizer + viaIR
```

Use **pnpm** (not npm/yarn). Node 24 required (see `.nvmrc`).

## Architecture

This is the on-chain Solidity layer for the **Nox protocol**, which enables confidential DeFi (cDeFi) by bridging on-chain contracts with off-chain TEE (Trusted Execution Environment) computations.

### Core flow

1. Application contracts call `NoxCompute` (or use the `Nox` SDK library) to request confidential operations (arithmetic, comparisons, transfers, etc.).
2. `NoxCompute` generates result handles on-chain and emits typed events that trigger off-chain TEE workers.
3. TEE workers compute results entirely off-chain; encrypted data is never submitted back on-chain.
4. EIP712-signed proofs are used for two purposes: validating user input handles (`validateInputProof`) and validating decryption results (`validateDecryptionProof`).

### Contract module structure

`NoxCompute` is composed of four abstract modules via multiple inheritance:

- **`contracts/modules/Common.sol`** — Shared base. Defines the ERC7201 namespaced storage struct (`NoxComputeStorage`), the storage accessor, and virtual cross-module function declarations (`_allowTransient`, `_validateAllowedForAll`).
- **`contracts/modules/Admin.sol`** — UUPS upgrade authorization (via OZ `UUPSUpgradeable`) and role-based config management. Two roles: `DEFAULT_ADMIN_ROLE` (grants/revokes roles) and `UPGRADER_ROLE` (authorizes upgrades and updates KMS key, gateway address, proof expiration).
- **`contracts/modules/ACL.sol`** — Access control for encrypted handles. Supports persistent access (`admins` mapping), transient access (EIP-1153 `tstore`/`tload` via OZ `TransientSlot`), viewer-only access, and public decryption flag.
- **`contracts/modules/Compute.sol`** — TEE compute operations: `wrapAsPublicHandle`, EIP712 proof validation (`validateInputProof`, `validateDecryptionProof`), arithmetic/comparison operators, and transfer/mint/burn.

**Top-level contracts:**

- **`contracts/NoxCompute.sol`** — Inherits `Admin`, `ACL`, `Compute`. Sole on-chain entry point. Holds `initialize()` and versioned `reinitializer` functions.
- **`contracts/interfaces/INoxCompute.sol`** — Public interface consumed by application contracts. Defines all errors, events, and function signatures.
- **`contracts/sdk/Nox.sol`** — Convenience library resolving the `NoxCompute` proxy address per chain. Exposes typed handle helpers (`ebool`, `euint16`, `euint256`, `eint16`, `eint256`).
- **`contracts/utils/TypeUtils.sol`** — `TEEType` enum covering 100+ types. Enum values must never be reordered or removed (append-only). Arithmetic is currently supported for `Uint16`, `Uint256`, `Int16`, `Int256`.
- **`contracts/utils/HandleUtils.sol`** — Distinguishes public handles from unique handles via bit 0 of byte 6.

### Handle types

- **Public handles** — deterministic from value + type + chainId; bit 0 of byte 6 = 0; accessible by anyone; no ACL needed. ACL mutations are blocked on public handles.
- **Unique handles** — opaque; bit 0 of byte 6 = 1; require an ACL entry granting access per address; support transient (single-tx via `tstore`) or persistent access.

### Deployment

Contracts are deployed via deterministic CREATE2 using the CreateX factory. The Hardhat Ignition module (`ignition/modules/NoxCompute.ts`) deploys implementation + ERC1967Proxy and encodes the initializer.

Key env vars for deployment: `RPC_URL`, `PRIVATE_KEY`, `INITIAL_OWNER`, `KMS_PUBLIC_KEY`, `ETHERSCAN_API_KEY`.

Deployed proxy addresses live in `contracts/sdk/Nox.sol` per chainId (Arbitrum Sepolia: `0xd464B198f06756a1d00be223634b85E0a731c229`; Ethereum Sepolia: `0x24Ef36Ec5b626D7DCD09a98F3083c2758F0F77bF`).

### Networks

| Network                 | ChainId  | Purpose                        |
| ----------------------- | -------- | ------------------------------ |
| default (EDR)           | 31337    | Local dev, OP stack simulation |
| arbitrumSepolia         | 421614   | Testnet                        |
| tenderlyArbitrumSepolia | 421614   | Tenderly fork                  |
| sepolia                 | 11155111 | L1 testnet                     |
| ethereum                | 1        | Mainnet                        |

### Test structure

- `test/unit/` — Foundry-style Solidity tests (`.t.sol`) and TypeScript tests for unit coverage.
- `test/integration/` — TypeScript integration tests hitting the full deploy + upgrade + operation flow.
- `test/utils/` — Shared test helpers.

### Solidity config

- Compiler: `0.8.35`, EVM version `osaka`.
- Production builds enable optimizer (`runs: 200`) + `viaIR` (`pnpm run deploy:production`).
- Prettier: 120-char line width, 4-space tabs for Solidity (`.prettierrc`).
- solhint: zero warnings allowed (`--max-warnings=0`).
- License: BUSL-1.1 (converts to MIT after the change date); SDK (`Nox.sol`) is MIT.
