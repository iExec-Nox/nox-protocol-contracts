# NoxCompute Upgrade Guide

`NoxCompute` is an OpenZeppelin `UUPSUpgradeable` proxy.
Upgrades are authorized by `UPGRADER_ROLE`.

Tooling:

- `pnpm run upgrade[:production]`: upgrade entry points.
- `scripts/upgrade.sh`: a wrapper that sets the per-network OZ manifest dir, then runs the TS script.
- `scripts/upgrade.ts`: runs `@openzeppelin/hardhat-upgrades` to check storage-layout safety and, atomically,
  calls `reinitialize()` via `upgradeToAndCall`.

## Initializer version

> [!NOTE]
> There is **one** version counter, `NoxCompute.INITIALIZER_VERSION`, shared by `initialize(...)` (new proxies)
> and `reinitialize(...)` (existing proxies).
>
> A fresh deploy runs `initialize`, landing **directly** at `INITIALIZER_VERSION`, so the
> `reinitialize` hatch is consumed at birth and can never be called on a fresh proxy.

## Pre-upgrade checklist

- [ ] New implementation compiles: `pnpm run build`.
- [ ] Full suite green: `pnpm run test`.
- [ ] Integration tests are green.
- [ ] Upgrade tested locally on a local fork of the target network.
- [ ] Storage layout is append-only — no reordered/removed/retyped existing vars; new
      state uses the ERC-7201 namespaced struct. (OZ plugin will also check this.)
- [ ] `TEEType` enum changes are append-only (never reorder/remove).
- [ ] Breaking changes are identified and clearly documented, with a migration strategy
      specified for existing apps.
- [ ] If the upgrade needs migration logic, put it in `reinitialize()` and **bump
      `INITIALIZER_VERSION`** by one. If not, leave `reinitialize()` empty but still bumped
      so the version advances.
- [ ] Update `initializer` tests to expect the new version number.
- [ ] OZ manifest for the target network exists under `.openzeppelin/` and matches the
      currently-deployed implementation (registered via `forceImport` in `deploy.ts`).
- [ ] Confirm the caller key (`PRIVATE_KEY`) holds `UPGRADER_ROLE` on the target proxy (command below).

## Running the upgrade

- [ ] Upgrades are run via the GitHub Actions workflow (never manually / locally).
- [ ] The workflow is always triggered from the `main` branch.
- [ ] Roll out in order: Tenderly environment first, then testnets, then mainnets.

`arbitrumSepolia` and its Tenderly fork `tenderlyArbitrumSepolia` share the same chainId (`421614`),
so their OZ manifests would collide in the default `.openzeppelin/` directory. `upgrade.sh`
gives only the Tenderly fork a dedicated manifest dir (via `MANIFEST_DEFAULT_DIR`); every other
network uses the default `.openzeppelin/`. Always go through `pnpm run upgrade`, not the raw
`hardhat run`.

## Post-upgrade checklist

- [ ] Upgrade tx succeeded (check the printed tx hash).
- [ ] New implementation address printed and differs from the old one
      (there is a log bug check the correct address on an explorer).
- [ ] Config intact: `gateway()`, `kmsPublicKey()`, `proofExpirationDuration()` return
      expected values.
- [ ] Verify the new implementation on the explorer: `pnpm run verify <network> --network <network>`.
- [ ] Merge the artifacts-update PR opened by the GHA run.
- [ ] All live networks are upgraded to the same `INITIALIZER_VERSION`.
- [ ] Publish a GitHub release for the new version.
- [ ] Update the dependent projects (`nox-confidential-contracts`, ...) to the new release if needed.

> [!NOTE]
> The on-chain initializer version can be read using the following command (low 8 bytes of the slot):
>
> ```bash
> cast storage <PROXY> \
>   0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00 \
>   --rpc-url <RPC>
> ```

## Gotchas

- There is a bug that prints the old implementation address instead of the new one, get the correct
  address from the manifest file.
- **`waitForTransactionReceipt` does not throw on revert**, always assert tx status
  before declaring success.
