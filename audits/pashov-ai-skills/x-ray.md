# X-Ray Report

> Nox Protocol | 1629 nSLOC | 125481f (`main`) | hardhat | 04/05/26

---

## 1. Protocol Overview

**What it does:** On-chain coordination layer for off-chain TEE confidential compute — manages the ACL of encrypted handles, validates gateway-signed input/decryption proofs, and emits events that drive off-chain TEE workers.

- **Users**: integrator app contracts (consume the Nox SDK library) on behalf of their end-users; an owner/admin controls config; a trusted off-chain Gateway issues EIP-712 proofs; off-chain TEE workers and KMS execute encrypted compute.
- **Core flow**: app obtains a gateway-signed input proof for a handle, calls `validateInputProof` to gain transient ACL on it, then chains arithmetic / comparison / composite operations whose results emit events the TEE workers consume.
- **Key mechanism**: 32-byte handle layout `[ver|chainId(4)|teeType|attrs|hash25]`; ACL has three strata — public handles (no ACL), transient (per-tx tstore), persistent (storage admins map); proofs gated by EIP-712 + ECDSA against a single gateway address.
- **Token model**: no native tokens. The "values" are encrypted plaintext registered through `wrapAsPublicHandle` or imported via gateway proofs.
- **Admin model**: single `OwnableUpgradeable` owner controls UUPS upgrades, gateway address, KMS public key, and proof expiration duration. No timelock, no two-step transfer.

For a visual overview of the protocol's architecture, see the [architecture diagram](architecture.svg).

### Contracts in Scope

| Subsystem           | Key Contracts                                    | nSLOC | Role                                                                                                                                 |
| ------------------- | ------------------------------------------------ | ----: | ------------------------------------------------------------------------------------------------------------------------------------ |
| Compute coordinator | `NoxCompute.sol`                                 |   601 | UUPS proxy contract: ACL, proof verification, compute-op event emission, owner-only config                                           |
| SDK library         | `sdk/Nox.sol`                                    |   887 | Internal-only library inlined into integrator contracts; resolves NoxCompute address per chainId; typed wrappers for every operation |
| Shared utilities    | `shared/HandleUtils.sol`, `shared/TypeUtils.sol` |   141 | `isPublicHandle` / `zeroHandle` bit-fiddling + TEEType enum (100 values, 5 currently supported) and arithmetic-type guard            |

Interfaces (`INoxCompute.sol` 264 nSLOC) and mocks (`mock/*` 542 nSLOC) excluded from in-scope counts.

### How It Fits Together

The core trick: every encrypted value is a deterministic 32-byte handle whose hash binds (operator, operands, contract address, seed, output index); on-chain code only routes ACL and emits events, while every actual ciphertext lives off-chain in the TEE.

### Onboarding an external value

```
User → App → Nox.fromExternal(extHandle, proof)
                ├─ extHandle = unwrap typed handle
                └─ NoxCompute.validateInputProof(handle, msg.sender, proof, type)
                      ├─ chainId byte == block.chainid                  ◄── handle binding
                      ├─ TypeUtils.typeOf(handle) == teeType
                      ├─ proof.length == 137 (owner|app|createdAt|sig65)
                      ├─ block.timestamp <= createdAt + expirationDur
                      ├─ ECDSA.recover(EIP-712(handle,owner,app,createdAt)) == $.gateway
                      └─ _allowTransient(handle, msg.sender)            ◄── tstore key=keccak(handle,sender)
```

### Confidential arithmetic

```
App → Nox.add(a, b) → NoxCompute.add(a, b)
                        └─ _executeArithmeticOperation(Add, [a,b], false)
                             ├─ _requireDefinedHandles(operands)        ◄── reverts on bytes32(0)
                             ├─ TypeUtils.validateArithmeticType(typeOf(a))
                             ├─ all operands typeOf == typeOf(a)
                             ├─ validateAllowedForAll(msg.sender, ops)
                             ├─ uniqueSeed = 0 if any operand confidential else ++uniqueSeedCounter
                             ├─ _generateHandle(Add, ops, type, 0, seed, ATTR_IS_UNIQUE)
                             └─ _allowTransient(result, msg.sender) + emit Add(...)
```

The `safeAdd`/`safeSub`/`safeMul`/`safeDiv` family follows the same path with `isSafeOperation=true`, producing a second handle at `outputIndex=1` of TEEType.Bool tagged "success".

### Composite ops (transfer / mint / burn)

```
App → Nox.transfer(balanceFrom, balanceTo, amount) → NoxCompute.transfer(...)
                        └─ _executeCompositeOperation(Transfer, [bf, bt, amt])
                             ├─ same prelude as arithmetic
                             ├─ generates 3 handles: success(Bool, idx0), result1(idx1), result2(idx2)
                             └─ transient access on all three for caller + emit Transfer(...)
```

`mint(balanceTo, amount, totalSupply)` and `burn(balanceFrom, amount, totalSupply)` use the same primitive with their own operator tag.

### Permission grant chain

```
App holds admin on H → Nox.allow(value, account) → NoxCompute.allow(handle, account)
                              └─ onlyAllowed(handle)  ◄── transient OR persistent OK
                              └─ admins[handle][account] = true   ◄── irreversible (no removeAdmin)

App → Nox.allowPublicDecryption(value) → NoxCompute.allowPublicDecryption(handle)
                              └─ onlyAllowed(handle) → isPubliclyDecryptable[handle] = true (irreversible)
```

### Public decryption verification

```
Anyone → Nox.publicDecrypt(value, proof) → NoxCompute.validateDecryptionProof(handle, proof)
                              ├─ proof.length >= 65
                              ├─ ECDSA.recoverCalldata(EIP-712(handle, keccak(plaintext))) == $.gateway
                              └─ returns plaintext bytes (NO check that handle is public-decryptable)
```

---

## 2. Threat & Trust Model

> **Bullet brevity rule.** One tight sentence per bullet.

### Protocol Threat Profile

> Protocol classified as: **Bridge-style oracle / signature relay** with **Governance** characteristics

The contract behaves like a bridge: a single off-chain Gateway signs EIP-712 attestations and an on-chain verifier accepts them as authoritative — the gateway's signing key is the trust root for every confidential value entering the system. The owner role is the secondary trust boundary, controlling UUPS upgrade authority and gateway/KMS rotation. There is no AMM, no lending, no token math; standard DeFi adversary classes (flash loaner, MEV searcher, oracle manipulator) do not apply. The relevant threats come from gateway compromise, transient/persistent ACL escalation, and the asymmetry between irreversible state writes and the function-level `onlyAllowed` gate.

### Actors & Adversary Model

| Actor             | Trust Level              | Capabilities                                                                                                                                                                                                                                                 |
| ----------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Owner             | Trusted                  | UUPS upgrade authority + 3 instant setters (gateway, kmsPublicKey, proofExpirationDuration). No timelock, no two-step transfer (`OwnableUpgradeable`, not `Ownable2Step`). Single key compromise is total takeover.                                          |
| Gateway           | Trusted (off-chain key)  | Only signer accepted by `validateInputProof` and `validateDecryptionProof`. Can attest any handle/owner/app/createdAt and any (handle, plaintext) pair — on-chain verifier does no ACL coupling. Stored as a single `address`, rotatable instantly by Owner. |
| App contract      | Bounded (per-handle ACL) | Calls compute / ACL ops only on handles where `isAllowed(handle, app)` is true (transient OR persistent). Can self-promote from transient → persistent admin via `allow()`, and irreversibly mark any handle it can reach as publicly decryptable.           |
| End user (EOA)    | Bounded                  | Initiates txs through an app contract; gains direct on-chain rights only when the proof's `appInProof == EOA` (i.e. EOA acts as its own app). Otherwise the EOA never appears in `validateInputProof`'s ACL grant.                                           |
| TEE workers / KMS | Trusted (off-chain)      | Read events to compute ciphertexts; produce gateway-co-signed plaintexts for decryption flows. Out of scope — but the protocol's confidentiality assumes they run honestly inside attested enclaves.                                                         |

**Adversary Ranking** (ordered by threat level for this protocol type):

1. **Compromised gateway key** — a single signing address gates every input proof and every decryption proof; one key compromise lets the holder forge ACL entries for any handle and reveal any encrypted value.
2. **Transient-access escalator** — any contract that legitimately receives transient access during a composed transaction can promote itself to persistent admin, add viewers, or permanently mark the handle publicly decryptable, all gated only by `onlyAllowed`.
3. **Compromised owner** — single-step `OwnableUpgradeable` controlling UUPS upgrade + gateway / KMS / expiration setters with no timelock; one mistyped `transferOwnership` is unrecoverable.
4. **Off-chain TEE / KMS misbehavior** — out of audit scope but the entire confidentiality property collapses if TEE attestation is broken; on-chain has no defense-in-depth against a TEE that decrypts handles it shouldn't.
5. **Integrator deploying on Arbitrum mainnet pre-deployment** — `Nox.noxComputeContract()` returns `address(0)` for chainid 42161; every SDK call reverts on `extcodesize`, bricking the integrator without a clear error.

See [entry-points.md](entry-points.md) for the full permissionless and ACL-gated entry point map.

### Trust Boundaries

- **Owner → contract** — `OwnableUpgradeable.transferOwnership` is single-step (`NoxCompute:25`); UUPS `_authorizeUpgrade` (`L897`) is owner-only with no timelock; one bad tx hands over upgrades, gateway, KMS, and expiration in the same instant.
- **Gateway → on-chain proof verifier** — `validateInputProof:301-304` and `validateDecryptionProof:320-323` accept any payload signed by `$.gateway`; `validateDecryptionProof` does NOT check `isPubliclyDecryptable[handle]`, so a single mis-signed off-chain decryption leaks plaintext on-chain regardless of ACL.
- **Transient grantee → handle ACL** — `onlyAllowed` (`L72`) treats `_isAllowedTransient` and `_isAllowedPersistent` as equivalent; `allow`, `addViewer`, `allowPublicDecryption` all live behind that single modifier and write irreversibly. The intended boundary ("transient is short-lived") is not enforced for the irreversible writes.
- **Initialization → live state** — `initialize` (`L98-105`) sets owner / kms / expiration but never `$.gateway`; the gap is mitigated only by OZ ECDSA reverting on zero-recovery.

### Key Attack Surfaces

- **Transient ACL → permanent ACL escalation** &nbsp;[[I-3](invariants.md#i-3), [I-4](invariants.md#i-4)] — `NoxCompute.allow:121-128`, `addViewer:173-180`, `allowPublicDecryption:193-199` all accept transient holders via `onlyAllowed`. Worth tracing every code path that calls `allowTransient(handle, X)` or hands `validateInputProof` a proof bound to an untrusted `app`, then checking what X can write before the tx ends.

- **`validateDecryptionProof` decoupled from `isPubliclyDecryptable`** &nbsp;[[X-1](invariants.md#x-1)] — `NoxCompute.validateDecryptionProof:310-325` verifies only the gateway signature; `$.isPubliclyDecryptable[handle]` and `HandleUtils.isPublicHandle(handle)` are never read. Worth confirming whether the off-chain gateway is the sole guard against revealing non-public handles, and what the recovery story is if a bad signature is ever issued.

- **Cross-party transient revocation in `disallowTransient`** &nbsp;[[I-5](invariants.md#i-5)] — `NoxCompute.disallowTransient:145-153` lets any `onlyAllowed` caller clear the tslot for an arbitrary `account` parameter (no `msg.sender == account` check). Worth tracing composed flows where multiple contracts hold transient rights to the same handle in one tx.

- **Irreversible write triad without inverse** &nbsp;[[I-1](invariants.md#i-1), [I-2](invariants.md#i-2)] — `admins`, `viewers`, and `isPubliclyDecryptable` mappings each have a single writer that flips false→true with no false-setter anywhere in scope (`L126`, `L178`, `L197`). The in-source TODO at `L35` ("Make viewer expirable") confirms the gap is acknowledged. Worth thinking about every long-lived handle's exposure to historical/forgotten admins.

- **`Nox.noxComputeContract` returns `address(0)` on Arbitrum mainnet** — `sdk/Nox.sol:28` (TODO from 2026-03-06) — every SDK call on chainid 42161 reverts via `extcodesize` on a non-deployed address. Worth confirming whether any integrator has shipped on mainnet against this branch.

- **`select` skips arithmetic-type validation** &nbsp;[[I-9](invariants.md#i-9)] — `NoxCompute.select:475-495` requires `condition` is Bool and that `ifTrue`/`ifFalse` types match, but never calls `TypeUtils.validateArithmeticType(resultType)`. Worth tracing whether off-chain TEE rejection is the only safety net for handles minted with unsupported types (e.g. `Bytes20`, `String`).

- **Owner setters are unbounded** &nbsp;[[I-7](invariants.md#i-7), [I-8](invariants.md#i-8)] — `setProofExpirationDuration:864-868` accepts `0` (instant DoS of every input proof) and `type(uint256).max`; `setKmsPublicKey:840-845` only checks non-empty (the documented 33-byte SEC1 format is unenforced). Worth confirming what guardrails exist off-chain.

- **`validateInputProof` does not check `attrs` byte** — `NoxCompute.validateInputProof:267-307` validates chainId byte 1-4 and type byte 5 but never inspects byte 6; if the gateway ever signs `attrs=0x00`, `_allowTransient` no-ops and the handle treats every caller as `isAllowed`.

- **Handle truncation to 200 bits** — `_generateHandle:782-797` keeps `keccak256 >> 56` (25 bytes); birthday bound ~2^100 — practically safe today, but the assumption is silent in the code and would break if the truncation parameter ever changes.

### Upgrade Architecture Concerns

- **Single-key UUPS** — `_authorizeUpgrade:897` gates upgrades with `onlyOwner` and no timelock; full storage layout / logic replacement is one tx away, and the same key holds gateway/KMS/expiration setters. Affected: `NoxCompute`.

- **Initialization ordering** — `initialize` (`L98-105`) does not take a gateway parameter; live deployments rely on a follow-up `setGateway` tx and on OZ ECDSA reverting on zero-recovery in the meantime. If proxy init is not atomic with `ERC1967Proxy` constructor, both the owner seat and the gateway are front-runnable.

- **`initializeV2` is permissionless** — `L114-116` is `reinitializer(2)` with no `onlyOwner`; safe today (only emits seed events) but any future addition to `_emitZeroHandleSeeds` becomes a permissionless side effect during the upgrade window.

### Protocol-Type Concerns

**As a Bridge-style signature relay:**

- **No nonce / consumed-proof tracking on input proofs** — `validateInputProof:267-307` only checks expiration; the bound app can re-consume the same proof any number of times within the window. Off-chain accounting that treats it as one-shot will miscount.
- **Decryption proofs have no expiration / no nonce** — `validateDecryptionProof:310-325` accepts any `(handle, plaintext, sig)` tuple forever (until gateway rotation).
- **Chain-ID truncated to uint32 in handles** — `HandleUtils.zeroHandle:32` and `_generateHandle:794` keep the low 32 bits; chains with id ≥ 2^32 would silently collide. EIP-712 domain still uses full 256-bit chainid so signatures remain chain-bound, but the in-handle field is not.

**As Governance-flavoured admin model:**

- No two-step ownership / no role separation between upgrader and parameter setter; any single Owner-tx is final.
- `setProofExpirationDuration` and `setKmsPublicKey` have no min/max bounds nor format checks.

### Temporal Risk Profile

**Deployment & Initialization:**

- Two-step deployment (`initialize` + `setGateway`) — UNMITIGATED window where `$.gateway == address(0)`; safe only because OZ ECDSA reverts on zero-recovery.
- Mainnet placeholder `address(0)` in SDK — UNMITIGATED until the team patches `Nox.sol:28` post-deployment.

**Governance & Upgrade Windows:**

- Instant gateway rotation invalidates every in-flight input proof; no event-driven warning, no timelock to let integrators react.

**Deprecation:** Not applicable — single-version protocol, no migration paths in scope.

### Composability & Dependency Risks

**Dependency Risk Map:**

> **Off-chain Gateway** — via `validateInputProof`, `validateDecryptionProof`
>
> - Assumes: only signs handles whose chainId/type/attrs match valid inputs; only signs decryption proofs for handles authorized for public decryption.
> - Validates: EIP-712 signature recovers to `$.gateway`. Handle chainId byte and type byte. NO check on attrs byte. NO check that handle is publicly decryptable.
> - Mutability: Owner can rotate via `setGateway` instantly.
> - On failure: gateway compromise = total ACL bypass; mis-signed decryption = silent plaintext leak.

> **Off-chain TEE workers + KMS** — via emitted events
>
> - Assumes: workers process every operation event correctly; KMS only releases plaintexts to authorized viewers.
> - Validates: nothing on-chain. Out of scope.
> - Mutability: out-of-scope infra.
> - On failure: protocol confidentiality collapses; on-chain has no defense-in-depth.

> **OpenZeppelin v5 ECDSA / EIP-712 / OwnableUpgradeable / UUPSUpgradeable** — via imports
>
> - Assumes: `ECDSA.recover` reverts on invalid signatures (not silently returns address(0)).
> - Validates: pinned via `package.json`; no internal modifications detected.
> - Mutability: pulled from upstream; updates require redeploy.
> - On failure: any future regression to the "return zero on bad sig" behavior re-opens the uninitialized-gateway window.

**Token Assumptions** _(unvalidated only)_: not applicable — no ERC-20/ERC-721 surfaces in scope.

**Shared State Exposure**: not applicable — protocol is the unique source of its own ACL state; no oracle role for downstream consumers.

---

## 3. Invariants

> ### 📋 Full invariant map: **[invariants.md](invariants.md)**
>
> A dedicated reference file contains the complete invariant analysis — do not look here for the catalog.
>
> - **24 Enforced Guards** (`G-1` … `G-24`) — per-call preconditions with `Check` / `Location` / `Purpose`
> - **9 Single-Contract Invariants** (`I-1` … `I-9`) — Conservation, Bound, StateMachine, Temporal
> - **2 Cross-Contract Invariants** (`X-1` … `X-2`) — caller/callee pairs that cross scope boundaries
> - **0 Economic Invariants** — protocol does not move value on-chain; no economic derivations apply
>
> The On-chain=No blocks (I-2, I-4, I-7, I-8, I-9, X-1) are the high-signal ones — each is simultaneously an invariant and a potential bug. Attack-surface bullets above cross-link directly into the relevant blocks.

---

## 4. Documentation Quality

| Aspect          | Status   | Notes                                                                                                                                                                                        |
| --------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| README          | Present  | `README.md` — covers build/test/deploy and architecture overview                                                                                                                             |
| NatSpec         | Adequate | Function-level NatSpec on every external function in `NoxCompute.sol`, the storage struct comment block, and library exports. No `@invariant` tags.                                          |
| Spec/Whitepaper | Missing  | No `whitepaper.md`, `spec.md`, `design.md`, or equivalent inside the repo                                                                                                                    |
| Inline Comments | Adequate | Handle-format diagram in `_generateHandle` (L758-773), explicit notes on transient vs persistent ACL, and on-chain comments around the Gateway trust boundary. Two known-gap TODOs (see §6). |

---

## 5. Test Analysis

| Metric          | Value                                                     | Source                      |
| --------------- | --------------------------------------------------------- | --------------------------- |
| Test files      | 13                                                        | File scan (always reliable) |
| Test functions  | 11                                                        | File scan (always reliable) |
| Line coverage   | Unavailable — `Hardhat must be installed locally (HHE22)` | Coverage tool               |
| Branch coverage | Unavailable — same reason as above                        | Coverage tool               |

### Test Depth

| Category                      | Count | Contracts Covered               |
| ----------------------------- | ----: | ------------------------------- |
| Unit                          |    11 | NoxCompute, Nox SDK (via mocks) |
| Integration                   |     0 | none                            |
| Fork                          |     0 | none                            |
| Stateless Fuzz                |     0 | none                            |
| Stateful Fuzz (Foundry)       |     0 | none                            |
| Stateful Fuzz (Echidna)       |     0 | none                            |
| Stateful Fuzz (Medusa)        |     0 | none                            |
| Formal Verification (Certora) |     0 | none                            |
| Formal Verification (Halmos)  |     0 | none                            |
| Formal Verification (HEVM)    |     0 | none                            |

### Gaps

- **No fuzz of any kind** — handle bit-layout encoding (`_generateHandle`), `validateInputProof` proof-byte parsing, and the type byte / attrs byte invariants are all stateless properties amenable to stateless fuzz; absent.
- **No invariant tests** — the false→true monotonicity of `admins` / `viewers` / `isPubliclyDecryptable` is exactly the kind of property invariant testing surfaces; absent.
- **No formal verification** — given how thin the contract is and how high the trust placed in the gateway, signature-verification correctness and ACL transition properties are good targets.
- **No fork test** — gateway behavior, EIP-712 domain across networks, and the SDK chain-id branching cannot be reproduced against a real chain.

---

## 6. Developer & Git History

> Repo shape: **normal_dev** — 113 commits over 104 days (2026-01-07 → 2026-04-21), 71 source-touching; analyzed branch: `main` at `125481f`.

### Contributors

| Author                              | Commits | Source Lines (+/-)          | % of Source Changes |
| ----------------------------------- | ------: | --------------------------- | ------------------: |
| Robin Le Caignec                    |      54 | +4205 / -1114               |               69.2% |
| Zied Guesmi                         |      46 | +1909 / -1485               |               30.7% |
| Christophe-iExec                    |       1 | +72 / -6                    |                0.1% |
| github-actions[bot]                 |       7 | release-please tooling only |                 n/a |
| iexec-s-nox-release-please-app[bot] |       4 | release-please tooling only |                 n/a |
| pjt                                 |       1 | tooling only                |                 n/a |

### Review & Process Signals

| Signal                       | Value                      | Assessment                                                                                                   |
| ---------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Unique contributors (humans) | 3                          | Two-dev concentration: Robin + Zied = 99.9%                                                                  |
| Merge commits                | 0 of 113 (0%)              | Squash-merge or rebase workflow — formal review not visible in git, must be confirmed via GitHub PRs         |
| Repo age                     | 2026-01-07 → 2026-04-21    | ~3.5 months                                                                                                  |
| Recent source activity (30d) | 3 commits since 2026-03-22 | Quiet — late activity is mostly cleanup                                                                      |
| Test co-change rate          | 87.3%                      | High file co-modification rate (commits touching source also touch tests) — measures co-change, not coverage |

### File Hotspots

| File                                   | Modifications | Note                                                         |
| -------------------------------------- | ------------: | ------------------------------------------------------------ |
| `contracts/sdk/Nox.sol`                |            37 | Highest churn — every type/operator addition touches the SDK |
| `contracts/NoxCompute.sol`             |            24 | Core ACL+compute contract; second-highest churn              |
| `contracts/interfaces/INoxCompute.sol` |            17 | Interface mirrors NoxCompute changes                         |
| `contracts/shared/TypeUtils.sol`       |            11 | Recently refactored (#114)                                   |
| `contracts/shared/HandleUtils.sol`     |           low | Stable since handle-v2 split                                 |
| `contracts/mock/NoxMock.sol`           |            10 | Test surface                                                 |

### Security-Relevant Commits

**Score** = weighted sum of fix-like signals. **10+ warrants a manual diff.**

| SHA       | Date       | Subject                                              | Score | Key Signal                                                                                |
| --------- | ---------- | ---------------------------------------------------- | ----: | ----------------------------------------------------------------------------------------- |
| `73359fc` | 2026-03-17 | refactor: Clean `validateDecryptionProof` (#88)      |    14 | hardening; removes runtime guards (-2/+1); spans access_control + fund_flows + signatures |
| `6f1271d` | 2026-04-09 | refactor: Refactor TypeUtils and fix coverage (#114) |    13 | bug fix; adds runtime guards (+11/-10); 5 source files                                    |
| `0ebd905` | 2026-03-17 | fix: compact-decryption-proof-format (#87)           |    13 | bug fix; adds runtime guards (+1)                                                         |
| `f60bc5d` | 2026-03-13 | feat: add verification (#81)                         |    13 | rewrites runtime guards (+8/-8) and access control (+4/-4)                                |
| `856b84a` | 2026-02-19 | fix: nox lib address resolution (#55)                |    13 | bug fix; touches fund_flows; SDK chain-id branching                                       |
| `b3fa6f5` | 2026-04-09 | fix: Emit zero handle seeds (#119)                   |    12 | bug fix in signature/auth area                                                            |
| `1110701` | 2026-02-23 | fix: revert with `UninitializedHandle` (#57)         |    12 | bug fix; +7 guards; large change (608 lines)                                              |
| `c7c5fca` | 2026-03-11 | feat: add on-chain decryption proof validation (#80) |    11 | hardening                                                                                 |
| `4f9f9ac` | 2026-02-12 | feat: Implement transfer/mint/burn (#44)             |    10 | feature; spans access_control + fund_flows + signatures                                   |
| `46f3032` | 2026-03-25 | feat: Restrict arithmetic types (#100)               |     9 | hardening; adds guard                                                                     |

### Dangerous Area Evolution

| Security Area                            | Commits | Key Files                                                          |
| ---------------------------------------- | ------: | ------------------------------------------------------------------ |
| fund_flows (compute / handle generation) |      37 | `contracts/sdk/Nox.sol`, `contracts/mock/NoxMock.sol`              |
| signatures (gateway proofs)              |      24 | `contracts/NoxCompute.sol`, `contracts/interfaces/INoxCompute.sol` |
| access_control (ACL)                     |      23 | `contracts/NoxCompute.sol`                                         |

All three security domains converge on the same ~2 files; the entire scope is security-sensitive.

### Forked Dependencies

None detected. OpenZeppelin pulled via npm (versioned dependency, not internalized).

### Technical Debt Markers

| File:Line                     | Type | Text                             | Author      | Date       |
| ----------------------------- | ---- | -------------------------------- | ----------- | ---------- |
| `contracts/NoxCompute.sol:35` | TODO | Make viewer expirable            | Zied Guesmi | 2026-02-25 |
| `contracts/sdk/Nox.sol:28`    | TODO | Update after mainnet deployment. | Zied Guesmi | 2026-03-06 |

Both TODOs sit in security-critical paths: the first is the irrevocable-viewer surface; the second is the `address(0)` mainnet branch.

### Security Observations

- **Two-dev concentration** — Robin Le Caignec (69%) + Zied Guesmi (31%) = ~100% of source authorship; review depth depends entirely on these two.
- **Zero merge commits** — formal multi-reviewer signals not visible in git; PR-level review must be confirmed on GitHub directly.
- **`Nox.sol` is the #1 hotspot AND #1 high-fix-score file** — 37 modifications, three score-13 commits (#87, #55, #57); highest-leverage review target.
- **`NoxCompute.sol` is #2 hotspot AND houses every ACL + signature surface** — 24 modifications across access_control / signatures / fund_flows simultaneously.
- **Late refactor of decryption-proof code** (#88 score 14, 2026-03-17) **and TypeUtils** (#114 score 13, 2026-04-09) — both within the audit window; treat as elevated regression risk.
- **Two TODOs in security-critical paths** — `viewer expirable` (`NoxCompute.sol:35`) aligns with the irrevocable-grant surface; `mainnet address` (`Nox.sol:28`) IS the mainnet-bricking attack surface.
- **One commit (#81 "feat: add verification") changed verification logic without test changes** — flagged by git analysis; worth confirming subsequent PRs added the tests.

### Cross-Reference Synthesis

- **`Nox.sol` is #1 in churn AND houses the mainnet `address(0)` placeholder** → highest-leverage review target; trace every chain-id branch and the `_resolveUndefinedHandle` semantics.
- **Decryption-proof path (`validateDecryptionProof`) was recently refactored to remove guards** (#88, score 14) → aligns with the X-1 finding (no `isPubliclyDecryptable` coupling); the refactor may have intentionally simplified the verifier without restoring defense-in-depth.
- **Both surviving TODOs are at the exact lines of high-priority attack surfaces** — `NoxCompute.sol:35` (irrevocable viewer / I-2) and `Nox.sol:28` (mainnet bricking). Treat them as authoritative tracking of known issues.
- **`feat: handle v2 with new field attribute` (#82, score 11+)** introduced the `attrs` byte that `validateInputProof` does NOT check — surface "validateInputProof does not check attrs byte" originates from this commit.

---

## X-Ray Verdict

**FRAGILE** — Adequate NatSpec and a clean code style mask a structurally fragile setup: zero fuzz / invariant / formal coverage on a contract whose entire job is signature verification + monotonic ACL, single-step Owner controlling instant gateway rotation and UUPS upgrades, two surviving security-critical TODOs, and a mainnet-branch placeholder that bricks the SDK.

**Structural facts:**

1. 1629 nSLOC across 4 in-scope files; one UUPS-upgradeable contract (`NoxCompute`), one library (`Nox.sol`) inlined into integrators, two pure-helpers.
2. Two human contributors authored 99.9% of source code over 104 days; zero merge commits in git (PR-level review is GitHub-only).
3. 13 test files / 11 test functions detected; coverage tool unavailable in this run (Hardhat install error). No fuzz, no invariant tests, no formal verification.
4. Three security-domain hotspots (access_control / signatures / fund_flows) all converge on `NoxCompute.sol` and `sdk/Nox.sol` — the same two files dominate hotspot churn AND high-score fix history.
5. Two TODOs in security-critical paths (irrevocable viewer at `NoxCompute.sol:35`, mainnet placeholder at `Nox.sol:28`) — both authored in February-March 2026, both unresolved at HEAD.
