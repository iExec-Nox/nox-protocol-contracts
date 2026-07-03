# NoxCompute Upgrade Guide

`NoxCompute` is an OpenZeppelin `UUPSUpgradeable` proxy.
Upgrades are authorized by `UPGRADER_ROLE`.

Tooling:

- `pnpm run upgrade[:production]`: upgrade entry points.
- `scripts/upgrade/upgrade.sh`: a wrapper that sets the per-network OZ manifest dir, then runs the TS script.
- `scripts/upgrade/upgrade.ts`: runs `@openzeppelin/hardhat-upgrades` to check storage-layout safety and, atomically,
  calls `reinitialize()` via `upgradeToAndCall`.

## Initializers

> [!NOTE]
> Two entry points:
>
> - `initialize(...)` — **fresh proxies only**. Uses the `initializer` modifier, so it is callable
>   exactly once, on a proxy that has never been initialized. It is unguarded and grants roles from
>   its arguments — hence it must NOT be a `reinitializer` (that would leave it callable on any proxy
>   below the target version and turn an upgrade without `upgradeToAndCall` into a takeover).
> - `reinitialize()` — **existing proxies, during upgrades**. `reinitializer(N) onlyRole(UPGRADER_ROLE)`;
>   run atomically via `upgradeToAndCall`. The `onlyRole` guard protects the migration hatch.
>   `N` should be bumped on each upgrade.

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
- [ ] If the upgrade needs migration logic, put it in `reinitialize()` and **bump its
      `reinitializer(N)` literal** by one. If not, leave `reinitialize()` empty or remove it.
- [ ] Update the reinitializer tests to expect the new version number.
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
