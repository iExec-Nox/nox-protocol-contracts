# NoxCompute — Documentation

## Diagrams

### Contract Inheritance

`NoxCompute` is a concrete UUPS-upgradeable contract assembled from four abstract modules. `Common` is the shared base that defines the ERC7201 storage struct and virtual cross-module hooks. `Admin` handles role-based configuration (KMS public key, gateway address, proof expiration) guarded by `UPGRADER_ROLE`. `ACL` manages persistent and transient access to encrypted handles using EIP-1153 transient storage. `Compute` implements EIP-712 proof validation and all TEE operation dispatch, emitting events consumed by off-chain TEE workers.

![Class diagram](./diagrams/class.svg)

---

### Storage Layout

`NoxComputeStorage` is stored at the ERC7201 namespaced slot derived from `"nox.storage.NoxCompute"` (`0x118a...cd00`). The struct holds the two-level ACL mappings (`admins`, `viewers`), the public-decryption flag, the KMS public key bytes, the gateway address, the proof expiration duration, and a counter used to guarantee handle uniqueness when all operands are public handles. The diagram is generated from `NoxComputeStorageStub`, a mock contract that mirrors the struct at sequential slots so sol2uml can render it.

![Storage layout](./diagrams/storage.svg)

---

## Sequence Diagrams

### 1. `wrapAsPublicHandle` — Create a deterministic public handle

A public handle is a deterministic, globally accessible commitment to a plaintext value. The same `(value, teeType, chainId, NoxCompute address)` always produces the same handle, so no ACL entry is needed — anyone can use it as a computation input. The emitted event lets off-chain TEE workers learn the plaintext behind the handle.

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

---

### 2. `validateInputProof` — Validate a gateway-issued handle proof

Before an app can use a user-supplied encrypted handle as a computation input, it must prove the handle was legitimately issued by the gateway for that specific owner and app. The gateway signs an EIP-712 `HandleProof` off-chain binding the handle to an owner, an app, and a timestamp. `validateInputProof` verifies all fields and, on success, grants the calling app transient ACL on the handle for the current transaction.

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

---

## Regenerate diagrams

```bash
pnpm run diagrams
```
