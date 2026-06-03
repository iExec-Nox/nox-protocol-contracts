# Invariant Map

> Nox Protocol | 24 guards | 11 inferred | 6 not enforced on-chain

---

## 1. Enforced Guards (Reference)

Per-call preconditions. Heading IDs below (`G-N`) are anchor targets from x-ray.md attack surfaces.

#### G-1

`require(account != address(0), InvalidZeroAddress());` · `NoxCompute.sol:63` · `notZeroAddress` modifier — prevents granting permissions to the zero address (would corrupt ACL semantics and is unrecoverable).

#### G-2

`require(isAllowed(handle, msg.sender), UnauthorizedSender(msg.sender));` · `NoxCompute.sol:72` · `onlyAllowed` modifier — central ACL gate; treats transient and persistent rights as equivalent (this is the surface for I-3, I-4).

#### G-3

`require(!HandleUtils.isPublicHandle(handle), PublicHandleACLForbidden());` · `NoxCompute.sol:82` · `notPublicHandle` modifier — public handles need no ACL by definition; reverts protect against meaningless writes to ACL maps for public handles.

#### G-4

`require(kmsPublicKey_.length != 0, InvalidEmptyBytes());` · `NoxCompute.sol:99` · ensures `initialize` cannot leave KMS unset (off-chain encryption clients depend on `kmsPublicKey()` returning non-empty).

#### G-5

`require(chainIdInHandle == bytes4(uint32(block.chainid)), InvalidProof(proof, "Handle chain id mismatch"));` · `NoxCompute.sol:274-277` · binds gateway-signed handles to the chain they were issued for; first defense against cross-chain proof replay (EIP-712 domain is the second).

#### G-6

`require(TypeUtils.typeOf(handle) == teeType, InvalidProof(proof, "Handle type mismatch"));` · `NoxCompute.sol:278` · ensures the caller-asserted TEE type matches the type encoded in the handle's byte 5; off-chain TEE workers depend on this binding.

#### G-7

`require(proof.length == 137, InvalidProof(proof, "Invalid proof length"));` · `NoxCompute.sol:279` · pins the calldata layout consumed by the inline assembly that follows (`owner(20) + app(20) + createdAt(32) + sig(65) = 137`).

#### G-8

`require(block.timestamp <= createdAt + $.proofExpirationDuration, InvalidProof(proof, "Proof expired"));` · `NoxCompute.sol:290-293` · bounds the replay window for input proofs; pairs with G-19 (no min on `proofExpirationDuration`).

#### G-9

`require(appInProof == msg.sender, InvalidProof(proof, "App mismatch"));` · `NoxCompute.sol:294` · binds the proof to a specific consuming contract — only the named `app` can present the proof, preventing cross-app theft.

#### G-10

`require(ownerInProof == owner, InvalidProof(proof, "Owner mismatch"));` · `NoxCompute.sol:295` · binds the asserted owner to the gateway-signed owner; equality check (not authorization).

#### G-11

`require(ECDSA.recover(eip712MessageHash, signature) == $.gateway, InvalidProof(proof, "Invalid signature"));` · `NoxCompute.sol:301-304` · trust root for input proofs — gateway compromise is total ACL compromise.

#### G-12

`require(decryptionProof.length >= 65, InvalidProof(decryptionProof, "Proof too short"));` · `NoxCompute.sol:315` · ensures at least a 65-byte signature is present before slicing; complementary to G-13.

#### G-13

`require(ECDSA.recoverCalldata(eip712MessageHash, decryptionProof[:65]) == $.gateway, InvalidProof(decryptionProof, "Invalid signature"));` · `NoxCompute.sol:320-323` · trust root for decryption proofs; the only on-chain check (no ACL coupling — see X-1).

#### G-14

`require(condition != bytes32(0) && ifTrue != bytes32(0) && ifFalse != bytes32(0), UndefinedHandle());` · `NoxCompute.sol:480-483` · select-specific defined-handle check (does not call `_requireDefinedHandles`).

#### G-15

`require(TypeUtils.typeOf(condition) == TEEType.Bool, UnsupportedType());` · `NoxCompute.sol:484` · select condition must be Bool; the only type validation that survives in this function.

#### G-16

`require(resultType == TypeUtils.typeOf(ifFalse), IncompatibleTypes());` · `NoxCompute.sol:486` · enforces matching branch types in select (does NOT enforce result type is arithmetic — see I-9).

#### G-17

`if (resultType != TypeUtils.typeOf(operands[i])) revert IncompatibleTypes();` · `NoxCompute.sol:599-601, 678-680` · loop guard in `_executeArithmeticOperation` and `_executeCompositeOperation` enforcing same-type operands.

#### G-18

`require(leftOperand != bytes32(0) && rightOperand != bytes32(0), UndefinedHandle());` · `NoxCompute.sol:647` · comparison-specific defined-handle check.

#### G-19

`require(TypeUtils.typeOf(rightOperand) == operandType, IncompatibleTypes());` · `NoxCompute.sol:650` · second comparison operand matches the first.

#### G-20

`require(operands[i] != bytes32(0), UndefinedHandle());` · `NoxCompute.sol:719` · `_requireDefinedHandles` loop — central guard preventing arithmetic/composite ops on uninitialized handles.

#### G-21

`require(newKmsPublicKey.length != 0, InvalidEmptyBytes());` · `NoxCompute.sol:841` · `setKmsPublicKey` setter mirror of G-4 (does NOT enforce 33-byte SEC1 length — see I-8).

#### G-22

`require(gatewayAddress != address(0), InvalidZeroAddress());` · `NoxCompute.sol:853` · `setGateway` non-zero check — ensures the gateway field, once set, is non-zero (does NOT cover the gap before any `setGateway` call — see I-7).

#### G-23

`require(t >= uint8(TEEType.Uint8) && t <= uint8(TEEType.Int256), NonArithmeticType());` · `TypeUtils.sol:155` · `validateArithmeticType` first check: type byte falls in the integer range.

#### G-24

`require(supportedType, UnsupportedArithmeticType());` · `TypeUtils.sol:161` · `validateArithmeticType` second check: type ∈ {Uint16, Uint256, Int16, Int256}.

---

## 2. Inferred Invariants (Single-Contract)

Inferred invariants are derived from structural analysis of the source code. Each block below cites one of five extraction methods in its `Derivation` field:

- **Δ-pair (delta-pair) analysis** — two or more storage variables in the same function body that change by equal-and-opposite amounts.
- **Guard lift** — a `require` / `if-revert` on a storage variable, promoted from per-call precondition to global property.
- **State-machine edge** — a storage variable transitions through discrete values via `require(state == A); state = B`, with no reverse path.
- **Temporal predicate** — a check tied to `block.timestamp`, `block.number`, or a stored duration/deadline.
- **NatSpec-stated global property** — developer-asserted invariant.

Each block is classified into one of five categories: `Conservation` · `Bound` · `Ratio` · `StateMachine` · `Temporal`.

---

#### I-1

`StateMachine` · On-chain: **Yes**

> For every `(handle, account)`, `admins[handle][account]` is monotonically non-decreasing — once set to `true` it remains `true` for the lifetime of the proxy.

**Derivation** — edge: `false@default → true@NoxCompute.sol:126` (only writer of `$.admins[handle][account]` is `allow()`); no reverse path exists in scope (grep on `$.admins` confirms no `= false` write).

**If violated** — admin removal would have to be added; today an over-broad grant is permanent. (Acknowledged: NatSpec at L28-32 enumerates admin powers.)

---

#### I-2

`StateMachine` · On-chain: **Yes** (monotonicity); the inverse property `viewers can be removed` is **explicitly NOT enforced** (see I-2-gap below).

> For every `(handle, viewer)`, `viewers[handle][viewer]` is monotonically non-decreasing — once set to `true` it remains `true` forever; same for `isPubliclyDecryptable[handle]`.

**Derivation** — edge: `false@default → true@NoxCompute.sol:178 (addViewer)` and `false@default → true@NoxCompute.sol:197 (allowPublicDecryption)`; no reverse path in scope (grep confirms no `= false` write to either field).

**If violated** — leaks of any encrypted value covered by the handle's viewers / public-decryption flag are permanent and unrecoverable. The in-source TODO at `NoxCompute.sol:35` ("Make viewer expirable") confirms the gap is acknowledged but unaddressed.

---

#### I-3

`Bound` · On-chain: **No**

> Persistent admin rights should only be writable by an existing persistent admin — i.e. `allow(H, X)` should require `_isAllowedPersistent(H, msg.sender)`, not just `isAllowed(H, msg.sender)`.

**Derivation** — guard-lift: `require(isAllowed(handle, msg.sender), UnauthorizedSender(msg.sender))` at `NoxCompute.sol:72`. Write sites of `admins[handle][account]`: `NoxCompute.sol:126` (single writer). The lifted property fails because `isAllowed` returns `true` for any caller with merely a transient grant (`L159 _isAllowedTransient`). The single writer therefore admits transient holders — every `allowTransient` recipient can mint persistent admins.

**If violated** — confirmed today: a contract holding only transient access can call `allow(H, anyAccount)` and the new persistent admin survives the transaction. Documented in the in-code comment at `L130-135` as the _responsibility of the application contract_ — the protocol itself does not constrain it.

---

#### I-4

`Bound` · On-chain: **No**

> The irreversible writes (`allowPublicDecryption`, `addViewer`) should be gated on persistent admin status, not on `isAllowed`.

**Derivation** — guard-lift: same `onlyAllowed` modifier at `L195` (allowPublicDecryption) and `L176` (addViewer). Same write-site enumeration as I-3 — both functions accept transient holders.

**If violated** — same shape as I-3, but the consequence is permanent worldwide decryption (`isPubliclyDecryptable[H] = true`) or permanent viewer addition; both writes have no inverse (see I-2).

---

#### I-5

`Bound` · On-chain: **No**

> `disallowTransient(H, account)` should clear only `msg.sender`'s own transient slot, or require persistent-admin authority over `account` — i.e. it should not let any allowed party revoke any other party's transient access.

**Derivation** — guard-lift: `onlyAllowed(handle)` at `L148`. The function body at `L149-152` derives the tstore key from the parameter `account`, not from `msg.sender`. There is no check that `msg.sender == account` and no admin-over-account requirement.

**If violated** — confirmed today: in any composed transaction where multiple contracts hold transient access to the same handle, any one of them can clear another's slot, breaking subsequent operations.

---

#### I-6

`Temporal` · On-chain: **Yes**

> Every accepted input proof was created within `[block.timestamp - proofExpirationDuration, block.timestamp]` (modulo unsigned addition).

**Derivation** — temporal: `require(block.timestamp <= createdAt + $.proofExpirationDuration, ...)` at `NoxCompute.sol:290-293`. The check uses storage variable `proofExpirationDuration` (stored, not parameter-only) and `createdAt` from the gateway-signed payload.

**If violated** — proofs older than the configured window are rejected; this is the protocol's only cross-tx replay defense beyond the EIP-712 domain. Tightly coupled to I-7.

---

#### I-7

`Bound` · On-chain: **No**

> `proofExpirationDuration > 0` so that no in-flight proof is instantly stale.

**Derivation** — guard-lift: `require(block.timestamp <= createdAt + $.proofExpirationDuration, ...)` at `L290-293` implies the lifted bound `$.proofExpirationDuration > 0` (otherwise every proof with `createdAt < block.timestamp` is stale on arrival). Write sites of `$.proofExpirationDuration`: `initialize` (`L102` sets `1 hours`) and `setProofExpirationDuration` (`L864-868` accepts any uint256, no min/max). The setter is the gap.

**If violated** — owner can DoS the entire input-proof onboarding pipeline by setting `proofExpirationDuration = 0` (every gateway-signed proof becomes "expired"). The setter has no event-driven warning either.

---

#### I-8

`Bound` · On-chain: **No**

> `kmsPublicKey` is a 33-byte SEC1 compressed secp256k1 public key (per NatSpec at `NoxCompute.sol:838`).

**Derivation** — NatSpec: `NoxCompute.sol:838` — _"Compressed SEC1 secp256k1 public key (33 bytes)"_ + guard-lift. Write sites of `$.kmsPublicKey`: `initialize` (`L103`) and `setKmsPublicKey` (`L840-845`). Both writers enforce only `length != 0` (G-4, G-21) — neither enforces `length == 33` nor the leading-byte (`0x02`/`0x03`) prefix that SEC1 compression requires.

**If violated** — off-chain encryption clients reading `kmsPublicKey()` may silently produce undecryptable ciphertexts.

---

#### I-9

`Bound` · On-chain: **No**

> Every confidential result handle has a TEE type from the supported set (Bool, Uint16, Uint256, Int16, Int256) — i.e. `validateArithmeticType` is enforced wherever a result handle is minted.

**Derivation** — guard-lift: `TypeUtils.validateArithmeticType(resultType)` at `_executeArithmeticOperation:597` and `_executeCompositeOperation:676` and `_executeComparisonOperation:649`. Write sites of result handles: those three internal helpers + `select` (`L475-495`). `select` does NOT call `validateArithmeticType` — it only enforces `condition` is Bool and `ifTrue`/`ifFalse` types match.

**If violated** — `select` can mint and ACL a result handle of any TEE type (e.g. String, Bytes20, any Uint8/Int8 / non-supported integer width); the off-chain TEE only supports five types per `allCurrentlySupportedTypes()`, so the result is dead-on-arrival. Trail unverified pending TEE-side rejection confirmation.

---

## 3. Inferred Invariants (Cross-Contract)

Trust assumptions that span contract boundaries. Each block cites both caller-side and callee-side code.

---

#### X-1

On-chain: **No**

> Plaintext is exposed by `validateDecryptionProof` only when the handle is publicly decryptable (`isPubliclyDecryptable[handle] == true` OR `HandleUtils.isPublicHandle(handle)`).

**Caller side** — `Nox.publicDecrypt` (`sdk/Nox.sol`, the `publicDecrypt(eX, proof)` family ~L2336-L2409) — the only on-chain consumer; it returns plaintext to the integrator without any pre-check on the handle's public-decryption flag.

**Callee side** — `NoxCompute.validateDecryptionProof:310-325` — verifies only the gateway signature; `$.isPubliclyDecryptable[handle]` and `HandleUtils.isPublicHandle(handle)` are never read.

**If violated** — a single mis-signed off-chain decryption (gateway bug, key compromise, replay) leaks plaintext on-chain regardless of ACL state. The on-chain layer has no defense-in-depth.

---

#### X-2

On-chain: **Yes** (within scope; off-chain side is a trust assumption)

> Every gateway-signed input handle has `attrs = ATTR_IS_UNIQUE_HANDLE` (i.e. byte 6 bit 0 = 1) — gateway never signs `attrs=0x00` (public).

**Caller side** — `NoxCompute.validateInputProof:267-307` — checks chainId byte (`L274-277`) and type byte (`L278`) but **not byte 6**; `_allowTransient(handle, msg.sender)` at `L306` early-returns when `isPublicHandle(handle)` is true, so attrs=0 produces a silent ACL no-op for what the gateway treats as a confidential handle.

**Callee side** — gateway code (off-chain). Within scope: only the `_generateHandle` (`NoxCompute.sol:782-797`) sets attrs=`ATTR_IS_UNIQUE_HANDLE` for confidential outputs and 0x00 for `_generatePublicHandle`. There is no on-chain code that mints a confidential handle with attrs=0.

**If violated** — caller of `validateInputProof` would receive no transient grant, and the handle would be treated as public by every downstream `isAllowed` short-circuit; the gateway's confidentiality intent would be silently degraded. Defense-in-depth gap.

---

## 4. Economic Invariants

No on-chain economic invariants apply: NoxCompute does not move tokens, hold balances, calculate prices, or perform financial conservation. All "value" flows are encrypted ciphertexts produced by off-chain TEE workers; their confidentiality and correctness are out-of-scope properties.
