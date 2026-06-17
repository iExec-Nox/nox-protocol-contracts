# Smart Contract Security Assessment

- **Repository:** https://github.com/iExec-Nox/nox-protocol-contracts
- **Tag:** [TODO](https://github.com/iExec-Nox/nox-protocol-contracts)
- **Commit:** [TODO](https://github.com/iExec-Nox/nox-protocol-contracts)

## Technical documentation

Technical documentation (architecture, storage layout, sequence diagrams) of the project
can be found in [`docs/`](../../docs/README.md).

## Scope

### In-scope files

| File                                   | Lines    |
| -------------------------------------- | -------- |
| `contracts/NoxCompute.sol`             | 54       |
| `contracts/interfaces/INoxCompute.sol` | 600      |
| `contracts/modules/Common.sol`         | 54       |
| `contracts/modules/Admin.sol`          | 121      |
| `contracts/modules/ACL.sol`            | 204      |
| `contracts/modules/Compute.sol`        | 659      |
| `contracts/utils/HandleUtils.sol`      | 46       |
| `contracts/utils/TypeUtils.sol`        | 203      |
| `contracts/sdk/Nox.sol`                | 1364     |
| **Total**                              | **3305** |

### Out of scope

- `contracts/mock/` — test-only contracts, never deployed

## Deployments

- Ethereum Sepolia: [0x24Ef36Ec5b626D7DCD09a98F3083c2758F0F77bF](https://sepolia.etherscan.io/address/0x24Ef36Ec5b626D7DCD09a98F3083c2758F0F77bF) ([v0.2.3](https://github.com/iExec-Nox/nox-protocol-contracts/releases/tag/v0.2.3))
- Arbitrum Sepolia: [0xd464B198f06756a1d00be223634b85E0a731c229](https://sepolia.arbiscan.io/address/0xd464B198f06756a1d00be223634b85E0a731c229) ([v0.2.4](https://github.com/iExec-Nox/nox-protocol-contracts/releases/tag/v0.2.4))

## Extended Details

- Coverage: [app.codecov.io](https://app.codecov.io/gh/iExec-Nox/nox-protocol-contracts)
- Slither static analysis: [nox-protocol-contracts/security/code-scanning](https://github.com/iExec-Nox/nox-protocol-contracts/security/code-scanning)
