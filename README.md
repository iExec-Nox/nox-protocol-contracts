# Nox Protocol Contracts

Smart contracts for the Nox protocol, including on-chain access control for encrypted handles and the compute gateway for confidential operations.

## What’s inside

- `IACL`: access control list for encrypted handles (admins, viewers, public decryption flags).
- `INoxCompute`: TEE compute entry point (handle validation, plaintext → encrypted conversion, arithmetic ops).
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
pnpm run build
```

## Test

Run only Solidity unit tests (no prerequisites):

```bash
pnpm run test:unit
```

Run all tests (unit + integration):

```bash
# Terminal 1: Start the off-chain stack (Anvil, gateway, KMS, ingestor, runner)
pnpm run service:up

# Terminal 2: Run tests
pnpm run test
```

For integration tests only:

```bash
# Terminal 1: Start services
pnpm run service:up

# Terminal 2: Run integration tests
pnpm run test:integration
```

Configure image versions in `.env.test`.

## Coverage

```bash
pnpm run coverage
```

## Formatting

```bash
pnpm run format
pnpm run format:check
```

## Deployment

The default network is a local EDR simulation. For external networks, configure the required variables:

- `RPC_URL`
- `PRIVATE_KEY`

```bash
pnpm run deploy
```

## Configuration notes

- Create2 salt is defined in [config/config.ts](config/config.ts).
- Default owner addresses and KMS public keys per network are also defined in [config/config.ts](config/config.ts).
- The SDK constants in [contracts/sdk/Nox.sol](contracts/sdk/Nox.sol) must match the deployed proxy addresses.
