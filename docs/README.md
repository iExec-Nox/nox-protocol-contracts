# Documentation

For a higher-level introduction to the protocol, see the [Nox documentation](https://docs.noxprotocol.io/getting-started/welcome).

`NoxCompute` is the on-chain entry point of the Nox protocol. It coordinates confidential DeFi operations by managing an access control list (ACL) for encrypted handles, validating EIP-712 proofs issued by a trusted gateway, and emitting events that trigger off-chain TEE computations. This document covers the contract architecture, storage layout, and the flow of each key operation from a Solidity perspective.

## Roles

| Role                 | Capabilities                                                                     |
| -------------------- | -------------------------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE` | Grants and revokes other roles                                                   |
| `UPGRADER_ROLE`      | Authorizes UUPS upgrades; sets gateway address, KMS public key, proof expiration |

Note: handle-level access is not role-based — it is managed per-handle via `allow`, `allowTransient`, `addViewer`, and `allowPublicDecryption`.

## Diagrams

### Contract Inheritance

`NoxCompute` is a concrete UUPS-upgradeable contract assembled from four abstract modules. `Common` is the shared base that defines the ERC7201 storage struct and virtual cross-module hooks. `Admin` handles role-based configuration (KMS public key, gateway address, proof expiration) guarded by `UPGRADER_ROLE`. `ACL` manages persistent and transient access to encrypted handles using EIP-1153 transient storage. `Compute` implements EIP-712 proof validation and all TEE operation dispatch, emitting events consumed by off-chain TEE workers.

<details>
<summary><strong>Class diagram</strong></summary>

![Class diagram](./diagrams/class.svg)

</details>

### Storage Layout

`NoxComputeStorage` is stored at the ERC7201 namespaced slot derived from `"nox.storage.NoxCompute"` (`0x118a...cd00`). The struct holds the two-level ACL mappings (`admins`, `viewers`), the public-decryption flag, the KMS public key bytes, the gateway address, the proof expiration duration, and a counter used to guarantee handle uniqueness when all operands are public handles. The diagram is generated from `NoxComputeStorageStub`, a mock contract that mirrors the struct at sequential slots so sol2uml can render it.

<details>
<summary><strong>Storage layout diagram</strong></summary>

![Storage layout](./diagrams/storage.svg)

</details>

## Sequence Diagrams

### 1. `wrapAsPublicHandle` — Create a deterministic public handle

A public handle is a deterministic, globally accessible commitment to a plaintext value. The same `(value, teeType, chainId, NoxCompute address)` always produces the same handle, so no ACL entry is needed — anyone can use it as a computation input. The emitted event lets off-chain TEE workers learn the plaintext behind the handle.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: wrapAsPublicHandle(value, teeType)
    Note over nox: - Check value fits teeType range <br> - Generate a new handle <br> - No ACL needed is needed since the handle is public
    nox->>nox: emit WrapAsPublicHandle(caller, plaintextValue, teeType, resultHandle)
    nox-->>app: result handle
```

</details>

### 2. `validateInputProof` — Validate a gateway-issued handle proof

Before an app can use a user-supplied encrypted handle as a computation input, it must prove the handle was legitimately issued by the gateway for that specific owner and app. The gateway signs an EIP-712 `HandleProof` off-chain binding the handle to an owner, an app, and a timestamp. `validateInputProof` verifies all fields and, on success, grants the calling app transient ACL on the handle for the current transaction.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    participant gateway as Gateway (off-chain)
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>gateway: request a new handle with proof for (value, owner, app)
    gateway-->>user: EIP-712 proof (owner | app | createdAt | signature) [137 bytes]

    user->>app: doSomething(handle, proof)
    app->>nox: validateInputProof(handle, owner, proof, teeType)
    Note over nox: - Reject if handle is a public handle <br> - Verify chainId encoded in handle matches current chain <br> - Verify type encoded in handle matches teeType <br> - Verify proof length is exactly 137 bytes <br> - Verify proof not expired <br> - Verify app in proof == msg.sender <br> - Verify owner in proof == owner <br> - Recover EIP-712 signature, verify signer == configured gateway
    nox->>nox: Grant transient ACL to msg.sender for handle
    nox-->>app: Ok
```

</details>

### 3. `add`, `sub` ... — Arithmetic, safe-arithmetic, and comparison operations

Applies to all arithmetic and comparison operators: `add`, `sub`, ..., `safeAdd`, `select`, ..., `eq`, ... The contract does not compute the result — it validates access, generates a unique result handle, and emits an event that TEE workers pick up to perform the actual computation off-chain.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: add(a, b)
    Note over nox: - Reject if any operand is bytes32(0) <br> - Verify both operands have same supported arithmetic type <br> - Verify msg.sender is allowed to use both operands <br> - Generate result handle and make it unique <br> (uniqueSeed counter if needed)
    nox->>nox: Grant transient ACL on result to msg.sender
    nox->>nox: emit Add(caller, a, b, result)
    nox-->>app: result handle
```

</details>

### 4. `transfer`, `mint`, `burn` — Optimized operations

Unlike simple arithmetic ops, these return two result handles plus a Bool success handle. The TEE computes the operation off-chain and the success handle's decrypted value indicates whether the operation succeeded (e.g. sufficient balance for transfer).

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: transfer(balanceFrom, balanceTo, amount)
    Note over nox: - Reject if any operand is bytes32(0) <br> - Verify all three operands have same supported arithmetic type <br> - Verify msg.sender is allowed to use all three operands <br> - Generate two result handles (newBalanceFrom, newBalanceTo) <br> - Generate one Bool success handle <br> - All three are unique handles (attributes=0x01)
    nox->>nox: Grant transient ACL on all three handles to msg.sender
    nox->>nox: emit Transfer(caller, balanceFrom, balanceTo, amount, success, newBalanceFrom, newBalanceTo)
    nox-->>app: success, newBalanceFrom, newBalanceTo
```

</details>

### 5. `allow` — Grant persistent access to a handle

Grants another address permanent admin access to a handle. The caller must already have access (transient or persistent). Once granted, persistent access cannot be revoked.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: allow(handle, account)
    Note over nox: - Reject if account is zero address <br> - Reject if handle is a public handle <br> - Verify msg.sender is allowed on handle (transient or persistent)
    nox->>nox: Store admins[handle][account] = true
    nox->>nox: emit Allowed(caller, account, handle)
    nox-->>app: Ok
```

</details>

### 6. `allowTransient` — Grant transient access to a handle

Grants another address access to a handle for the current transaction only. Access is stored in EIP-1153 transient storage and is automatically cleared at the end of the transaction.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: allowTransient(handle, account)
    Note over nox: - Reject if account is zero address <br> - Reject if handle is a public handle <br> - Verify msg.sender is allowed on handle (transient or persistent)
    nox->>nox: tstore allowed[handle][account] = true
    nox-->>app: Ok
```

</details>

### 7. `addViewer` — Grant decryption-only access to a handle

Grants an address viewer access to a handle. A viewer can request decryption off-chain from the TEE but cannot use the handle as a computation input. Persistent and irrevocable.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: addViewer(handle, viewer)
    Note over nox: - Reject if viewer is zero address <br> - Reject if handle is a public handle <br> - Verify msg.sender is allowed on handle (transient or persistent)
    nox->>nox: Store viewers[handle][viewer] = true
    nox->>nox: emit ViewerAdded(caller, viewer, handle)
    nox-->>app: Ok
```

</details>

### 8. `allowPublicDecryption` — Make a handle publicly decryptable

Marks a handle as publicly decryptable, allowing anyone to request its decryption from the TEE without any ACL entry. This is irreversible.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>app: doSomething()
    app->>nox: allowPublicDecryption(handle)
    Note over nox: - Reject if handle is a public handle <br> - Verify msg.sender is allowed on handle (transient or persistent)
    nox->>nox: Store isPubliclyDecryptable[handle] = true
    nox->>nox: emit MarkedAsPubliclyDecryptable(caller, handle)
    nox-->>app: Ok
```

</details>

### 9. `validateDecryptionProof` — Verify a TEE decryption result

To read an encrypted value, a user requests decryption from the TEE off-chain. The TEE returns an EIP-712 signed proof binding the handle to the decrypted result. `validateDecryptionProof` verifies the proof on-chain and extracts the plaintext. This is a `view` function with no ACL check — access control for decryption is enforced by the Gateway (running inside TEE) according to the on-chain state.

<details>
<summary><strong>Sequence diagram</strong></summary>

```mermaid
sequenceDiagram
    autonumber
    participant gateway as Gateway (off-chain)
    actor user as User
    participant app as App
    participant nox as NoxCompute

    user->>gateway: request decryption of handle
    Note over gateway: Check caller is allowed onchain <br> (admin, viewer, or handle is publicly decryptable)
    gateway-->>user: EIP-712 proof (signature | decryptedResult)

    user->>app: doSomething(handle, decryptionProof)
    app->>nox: validateDecryptionProof(handle, decryptionProof)
    Note over nox: - Verify proof length <br> - Recover EIP-712 signature <br> - Verify signer == configured gateway
    nox->>nox: Extract decrypted result value
    nox-->>app: plaintext value
```

</details>
