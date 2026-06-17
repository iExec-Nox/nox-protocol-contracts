# Entry Point Map

> Nox Protocol | 22 entry points | 3 permissionless | 15 ACL-gated | 4 admin-only (+ 2 initializers)

---

## Protocol Flow Paths

### Setup (Owner)

`new ERC1967Proxy(NoxCompute, initialize(initialOwner, kmsPublicKey))` → `setGateway(gw)` ◄── must precede first `validateInputProof`

[(Optional later)] → `initializeV2()` ◄── only valid for already-deployed v0.1.0 proxies; reinitializer(2) re-emits zero seeds

### Onboarding an external value (App Contract)

`[setup above]` → `Gateway.signOffChain(handle, owner, app, createdAt)` ◄── off-chain — gateway must be set
→ `validateInputProof(handle, owner, proof, type)` ◄── proof unexpired, app == msg.sender
├─→ `_allowTransient(handle, app)`
└─→ [in same tx] compute paths below

### Confidential compute (App Contract holds transient or persistent admin)

`[onboarding above]` → `add` / `sub` / `mul` / `div` / `eq` / `ne` / `lt` / `le` / `gt` / `ge` / `safeAdd` / `safeSub` / `safeMul` / `safeDiv`
├─→ result handle: caller granted transient
└─→ `select(condition, ifTrue, ifFalse)`
└─→ `transfer` / `mint` / `burn` (3-output composite)

### Permission management (App Contract)

`[onboarding above]` → `allow(handle, account)` ◄── persistent admin write (irreversible)
└─→ `addViewer(handle, viewer)` ◄── viewer write (irreversible)
└─→ `allowPublicDecryption(handle)` ◄── isPubliclyDecryptable=true (irreversible)
└─→ `allowTransient(handle, account)` ◄── tstore for current tx
└─→ `disallowTransient(handle, account)` ◄── clears any account's tstore (NOT only msg.sender)

### Public decryption verification (Anyone)

`Gateway.signOffChain(handle, decryptedResult)` → `validateDecryptionProof(handle, proof)` ◄── view, no ACL coupling
└─→ returns plaintext

### Plaintext registration (Anyone)

`wrapAsPublicHandle(value, type)` ◄── deterministic; no ACL — same (value, type) always returns same handle

### Admin operational changes (Owner)

`setKmsPublicKey(bytes)` ◄── any non-empty bytes accepted
`setGateway(address)` ◄── any non-zero address accepted (instantly invalidates in-flight proofs)
`setProofExpirationDuration(uint256)` ◄── any uint256 accepted (0 = global DoS, max = no expiry)
`upgradeToAndCall(newImpl, data)` ◄── owner-gated UUPS upgrade

---

## Permissionless

### `NoxCompute.wrapAsPublicHandle()`

| Aspect           | Detail                                                                                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Visibility       | external                                                                                                                                               |
| Caller           | Anyone                                                                                                                                                 |
| Parameters       | `value (user-controlled)`, `teeType (user-controlled)`                                                                                                 |
| Call chain       | `→ NoxCompute._generatePublicHandle() → _generateHandle() → _allowTransient(result, msg.sender)` (no-op for public handle) `→ emit WrapAsPublicHandle` |
| State modified   | possibly `$.uniqueSeedCounter` if all operands are public (here: 1 operand, the raw value, treated by `isPublicHandle` per byte 6 of the value bytes)  |
| Value flow       | None                                                                                                                                                   |
| Reentrancy guard | no                                                                                                                                                     |

### `NoxCompute.validateInputProof()`

| Aspect           | Detail                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Visibility       | public                                                                                                                    |
| Caller           | App contract (must equal `appInProof`)                                                                                    |
| Parameters       | `handle (gateway-signed)`, `owner (gateway-signed match)`, `proof (gateway-signed)`, `teeType (must match handle byte 5)` |
| Call chain       | `→ TypeUtils.typeOf → ECDSA.recover → _allowTransient(handle, msg.sender)` (no-op if handle has attrs=0x00)               |
| State modified   | transient slot `keccak(handle, msg.sender)` only                                                                          |
| Value flow       | None                                                                                                                      |
| Reentrancy guard | no — function makes no external calls                                                                                     |

### `NoxCompute.initializeV2()`

| Aspect           | Detail                                                  |
| ---------------- | ------------------------------------------------------- |
| Visibility       | public, `reinitializer(2)`                              |
| Caller           | Anyone (one-time)                                       |
| Parameters       | (none)                                                  |
| Call chain       | `→ _emitZeroHandleSeeds() → emit WrapAsPublicHandle x5` |
| State modified   | `_initializableStorage` reinitializer slot only         |
| Value flow       | None                                                    |
| Reentrancy guard | no                                                      |

---

## ACL-Gated (`onlyAllowed(handle)` — transient OR persistent)

### Permission writes (irreversible)

| Contract   | Function                             | Parameters                                                      | State Modified                         |
| ---------- | ------------------------------------ | --------------------------------------------------------------- | -------------------------------------- |
| NoxCompute | `allow(handle, account)`             | `handle`, `account (user-controlled)`                           | `admins[handle][account] = true`       |
| NoxCompute | `addViewer(handle, viewer)`          | `handle`, `viewer (user-controlled)`                            | `viewers[handle][viewer] = true`       |
| NoxCompute | `allowPublicDecryption(handle)`      | `handle`                                                        | `isPubliclyDecryptable[handle] = true` |
| NoxCompute | `allowTransient(handle, account)`    | `handle`, `account (user-controlled)`                           | tstore `keccak(handle, account) = 1`   |
| NoxCompute | `disallowTransient(handle, account)` | `handle`, `account (user-controlled — NOT bound to msg.sender)` | tstore `keccak(handle, account) = 0`   |

### Compute primitives (2-operand arithmetic / comparison)

| Contract   | Function                                      | Parameters                                  | State Modified                                                                         |
| ---------- | --------------------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------- |
| NoxCompute | `add` / `sub` / `mul` / `div`                 | `(left, right)` both gateway/handle-derived | possibly `$.uniqueSeedCounter`; tstore for `result`                                    |
| NoxCompute | `eq` / `ne` / `lt` / `le` / `gt` / `ge`       | `(left, right)`                             | same as above; result is Bool                                                          |
| NoxCompute | `safeAdd` / `safeSub` / `safeMul` / `safeDiv` | `(left, right)`                             | same as above + tstore for `success` handle                                            |
| NoxCompute | `select(condition, ifTrue, ifFalse)`          | three handles                               | possibly counter; tstore for `result`. **No `validateArithmeticType` on result type.** |

### Composite ops

| Contract   | Function                                   | Parameters    | State Modified                                                           |
| ---------- | ------------------------------------------ | ------------- | ------------------------------------------------------------------------ |
| NoxCompute | `transfer(balanceFrom, balanceTo, amount)` | three handles | possibly counter; tstore for `success`, `newBalanceFrom`, `newBalanceTo` |
| NoxCompute | `mint(balanceTo, amount, totalSupply)`     | three handles | possibly counter; tstore for 3 outputs                                   |
| NoxCompute | `burn(balanceFrom, amount, totalSupply)`   | three handles | possibly counter; tstore for 3 outputs                                   |

All compute primitives share the call chain: `→ _executeArithmeticOperation / _executeComparisonOperation / _executeCompositeOperation → _requireDefinedHandles → TypeUtils.validateArithmeticType (except select) → validateAllowedForAll(msg.sender, operands) → _generateHandleUniqueSeed → _generateHandle x N → _allowTransient(result, msg.sender) x N → emit <Op>`.

---

## Admin-Only (`onlyOwner`)

| Contract   | Function                                  | Parameters                                                                                               | State Modified                                   |
| ---------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| NoxCompute | `setKmsPublicKey(newKmsPublicKey)`        | `newKmsPublicKey (admin-provided, only `length != 0` enforced — 33-byte SEC1 documented but unverified)` | `$.kmsPublicKey`                                 |
| NoxCompute | `setGateway(gatewayAddress)`              | `gatewayAddress (admin-provided, only non-zero enforced)`                                                | `$.gateway`                                      |
| NoxCompute | `setProofExpirationDuration(newDuration)` | `newDuration (admin-provided, no min/max)`                                                               | `$.proofExpirationDuration`                      |
| NoxCompute | `upgradeToAndCall(newImpl, data)` (UUPS)  | `newImpl (admin-provided)`                                                                               | implementation slot, runs `data` as delegatecall |

`_authorizeUpgrade(newImplementation)` is the gate (`NoxCompute.sol:897`) — `onlyOwner` only, no timelock, no two-step.

## Initializers (one-time)

| Contract   | Function                                  | Notes                                                                                                                                                                                                                            |
| ---------- | ----------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NoxCompute | `initialize(initialOwner, kmsPublicKey_)` | `initializer` — sets owner, kmsPublicKey, proofExpirationDuration=1h, emits zero handle seeds. **Does NOT set `$.gateway`** — must be followed by `setGateway`. Front-runnable if proxy deployment is not atomic with this call. |
| NoxCompute | `initializeV2()`                          | `reinitializer(2)` — listed under Permissionless above.                                                                                                                                                                          |
