# Nox Protocol Contracts

Smart contracts for the Nox protocol, including on-chain access control for encrypted handles and the compute gateway for confidential operations.

## What’s inside

- `ACL`: access control list for encrypted handles (admins, viewers, public decryption flags).
- `NoxCompute`: TEE compute entry point (handle validation, plaintext → encrypted conversion, arithmetic ops).
- `Nox` SDK library: convenience wrapper for app contracts that call `NoxCompute` and `ACL`.

## Requirements

- Node.js version from `.nvmrc`
- `pnpm` (see `packageManager` in `package.json`)

## Setup

```bash
nvm install && nvm use
pnpm install
```

## Build

```bash
pnpm build
```

## Test

```bash
pnpm test
```

## Coverage

```bash
pnpm coverage
```

## Formatting

```bash
pnpm format
pnpm format:check
```

## Deployment

The default network is a local EDR simulation. For external networks, configure the required variables:

- `RPC_URL`
- `PRIVATE_KEY`

```bash
pnpm deploy
```

## Configuration notes

- Create2 salt is defined in [config/config.ts](config/config.ts).
- Default owner addresses and KMS public keys per network are also defined in [config/config.ts](config/config.ts).
- The SDK constants in [contracts/sdk/Nox.sol](contracts/sdk/Nox.sol) must match the deployed proxy addresses.
