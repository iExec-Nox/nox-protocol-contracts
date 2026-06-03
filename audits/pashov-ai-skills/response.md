# Audit Response — Pashov AI Skills Security Review

**Audit date:** 2026-05-04  
**Response date:** 2026-06-03  
**Audited files:** `contracts/NoxCompute.sol`, `contracts/shared/TypeUtils.sol`, `contracts/shared/HandleUtils.sol`, `contracts/sdk/Nox.sol`  
**Note:** Audit was performed on an older version of the codebase. Where findings no longer apply, the reason is documented below.

---

## Findings

### #1 [85] — Transient ACL holder can permanently mark handle publicly decryptable

**Response: By design.**

Transient and persistent access are equal trust levels. Transient access is a convenience mechanism for single-transaction flows, not a reduced privilege. Gating `allowPublicDecryption` on persistent-only would break valid use cases where the caller holds legitimate but short-lived access. The distinction between transient and persistent is operational, not security-level.

---

### #2 [82] — Transient ACL holder can mint persistent admins for third parties

**Response: By design.**

Same reasoning as #1. Transient and persistent access are equal trust levels. A transient holder has the same rights as a persistent one — including the ability to delegate persistent access to third parties.

---

### #3 [80] — Viewer rights are permanent and reachable from transient access

**Response: By design.**

Transient access granting viewer rights is intentional (same trust level as persistent). The absence of `removeViewer` is a deliberate design choice. Viewer expiration is on the roadmap as an optional future feature (tracked internally via the existing TODO in `Common.sol`).

---

### #4 [80] — SDK returns `address(0)` for Arbitrum mainnet, bricking integrators

**Response: Out of date. Fixed.**

The current `Nox.sol` does not return `address(0)` for any chain. Unknown chains — including Arbitrum mainnet (42161) — fall through to `revert("Nox: Unsupported chain")`, giving integrators a clear error. The `address(0)` path with the `// TODO` comment existed in an older version reviewed by the auditor.

---

### #5 [75] — `disallowTransient` allows cross-party transient revocation (DoS)

**Response: By design.**

`disallowTransient` is a low-level primitive. Correct usage in multi-contract orchestration flows is the responsibility of application contract developers. The protocol provides the mechanism; safe orchestration patterns are the integrator's concern.

---

### #6 [75] — Gateway address not set during `initialize`

**Response: Out of date. Fixed.**

`NoxCompute.initialize` explicitly accepts and sets `$.gateway` (`NoxCompute.sol:45`). The audited version predated the addition of the `gateway` parameter to the initializer.

---

### #7 [75] — `validateDecryptionProof` has no on-chain ACL coupling

**Response: Acknowledged. By design, enhancement considered and rejected.**

`validateDecryptionProof` is intentionally a pure signature verifier. ACL enforcement is the gateway's responsibility — it should only sign decryption proofs for handles that the requester is authorized to decrypt. Adding an on-chain `msg.sender` ACL check was considered: checking `isViewer(handle, msg.sender)` was explored, but in the standard flow `msg.sender` is the application contract acting on behalf of an end user, and does not hold ACL access to the handle. Such a check would break valid flows without meaningful security benefit given the trust model. Defense-in-depth at this layer remains a future consideration.

---

## Leads

### Lead #1 — `select` does not validate result type is supported

**Response: False positive.**

`select` calls `validateOperationTypes(ifTrue, ifFalse)` (`Compute.sol:405`), which internally calls `validateArithmeticType`. The result type is validated.

---

### Lead #2 — `validateInputProof` does not check attrs byte

**Response: Acknowledged. Fix planned.**

Byte 6 (attrs) of the handle is not validated in `validateInputProof`. A public handle (attrs bit 0 = 0) passed to this function would cause `_allowTransient` to silently no-op, potentially allowing ACL bypass. A `require(!HandleUtils.isPublicHandle(handle), ...)` check will be added to `validateInputProof` — public handles are deterministic and do not require a gateway proof.

---

### Lead #3 — `setProofExpirationDuration` unbounded

**Response: Acknowledged. Accepted risk.**

`UPGRADER_ROLE` is a trusted role. Adding bounds would increase complexity without meaningful security benefit given the trust model. The risk of misconfiguration is accepted.

---

### Lead #4 — Single-step ownership on UUPS proxy

**Response: Out of date. Fixed.**

The audit observed `OwnableUpgradeable`. Version 0.2.3 migrated to `AccessControlUpgradeable` (`initializeV3`). There is no `transferOwnership` function. `_authorizeUpgrade` is gated by `UPGRADER_ROLE`.

---

### Lead #5 — `setKmsPublicKey` missing format/length check

**Response: Acknowledged. Fix planned.**

Only `length != 0` is currently enforced. The documented format is a compressed SEC1 secp256k1 public key (33 bytes). A `require(newKmsPublicKey.length == 33, ...)` check will be added to `setKmsPublicKey` to prevent silently malformed keys from causing off-chain encryption failures.

---

### Lead #6 — `validateInputProof` replay within expiration window

**Response: Not a concern.**

Replay within the expiration window is idempotent on-chain — no state changes, no events emitted. The caller only pays gas. By design.

---

### Lead #7 — Chain-ID truncated to 32 bits in handles

**Response: Not a real concern.**

All current and foreseeable target chains have IDs well within uint32 range (max ~4.3 billion). No EVM chain with an ID exceeding this range exists or is planned. The risk is theoretical.

---

### Lead #8 — `Nox._resolveUndefinedHandle` silently substitutes the public zero handle

**Response: By design.**

Uninitialized handles resolve to the typed zero handle — analogous to default zero values in traditional computation. Application developers are responsible for null-checking when needed. This is a deliberate ergonomic choice.

---

### Lead #9 — `wrapAsPublicHandle` does not validate plaintext fits TEE type

**Response: Acknowledged. Fix planned for future release.**

No bounds validation is performed on `value` vs `teeType`. A Bool can wrap `0xFF`, a Uint16 can wrap a value exceeding 65535. A `validateValueFitsType` utility will be added to `TypeUtils` for currently supported types: Bool (0 or 1), Uint16/Int16 (fits uint16 range). Uint256/Int256 accept any bytes32. Other types remain TEE-side responsibility.

---

### Lead #10 — `wrapAsPublicHandle` calls `_allowTransient` on a public handle (dead code)

**Response: Acknowledged. Fix planned.**

`_allowTransient` is called on the result of `wrapAsPublicHandle` but silently no-ops since the result is always a public handle. Dead code. Will be removed in a future cleanup.

---

### Lead #11 — `HandleUtils.isPublicHandle` only masks bit 0 of byte 6

**Response: Not an issue.**

Bit 0 of the attrs byte is the sole public/unique discriminator by design. Bits 1–7 are reserved for future attributes. Any future addition will be accompanied by updated validation logic at that time.

---

### Lead #12 — Nox SDK `addViewer`/`allowPublicDecryption` not consistent with `allow` for public handles

**Response: Acknowledged. Fix planned.**

`Nox.allow` silently skips public handles via `_allowIfNotPublic`, but `Nox.addViewer` and `Nox.allowPublicDecryption` call NoxCompute directly and revert via `notPublicHandle`. `Nox.addViewer` and `Nox.allowPublicDecryption` will be updated to silently skip public handles, consistent with `Nox.allow` behavior — public handles are already accessible by everyone and require no grant.

---

### Lead #13 — `disallowTransient` reverts on public handles while `_allowTransient` silently skips

**Response: Not valid.**

The auditor compared the external `disallowTransient` (has `notPublicHandle` modifier) with the internal `_allowTransient` helper (silently skips). The correct comparison is external vs external: `allowTransient` also has `notPublicHandle` (`ACL.sol:70`) — both external functions revert on public handles symmetrically. The internal `_allowTransient` skips for efficiency in compute operations. No asymmetry on the public surface.

---

### Lead #14 — `initializeV2` is permissionless

**Response: Acknowledged. No action needed.**

`initializeV2` is intentionally permissionless — it only emits events with no state changes. This is documented in the contract's code comments. Safe today and in any future extension that follows the same event-only pattern.

---

### Lead #15 — Front-run vulnerable initialization

**Response: Not a concern.**

Deployment is atomic. `initialize` calldata is encoded and passed directly to the `ERC1967Proxy` constructor in a single transaction (`ignition/modules/NoxCompute.ts:18-26`). No window exists between proxy creation and initialization.
