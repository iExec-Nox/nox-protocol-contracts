# Smart Contract Security Assessment

- **Repository:** https://github.com/iExec-Nox/nox-protocol-contracts
- **Commit:** [90c30b8b43d0e09a3b902e08a8ff05fc7125ef01](https://github.com/iExec-Nox/nox-protocol-contracts/tree/90c30b8b43d0e09a3b902e08a8ff05fc7125ef01)

## Technical documentation

Technical documentation (architecture, storage layout, sequence diagrams) of the project
can be found in [`docs/`](../../docs/README.md).

## Scope

### In-scope files

```
$ cloc --by-file --exclude-dir=mock contracts
      12 text files.
       9 unique files.
       4 files ignored.

github.com/AlDanial/cloc v 1.98  T=0.01 s (871.8 files/s, 320127.8 lines/s)
---------------------------------------------------------------------------------------
File                                                blank        comment           code
---------------------------------------------------------------------------------------
contracts/sdk/Nox.sol                                 153            290            921
contracts/modules/Compute.sol                          30             94            535
contracts/interfaces/INoxCompute.sol                   46            291            263
contracts/utils/TypeUtils.sol                           9             46            148
contracts/modules/ACL.sol                              20             60            124
contracts/modules/Admin.sol                            13             48             60
contracts/modules/Common.sol                            7             20             27
contracts/NoxCompute.sol                                4             27             23
contracts/utils/HandleUtils.sol                         4             29             13
---------------------------------------------------------------------------------------
SUM:                                                  286            905           2114
---------------------------------------------------------------------------------------
```

### Out of scope

- `contracts/mock/` — test-only contracts, never deployed

## Deployments

- Ethereum Sepolia: [0x24Ef36Ec5b626D7DCD09a98F3083c2758F0F77bF](https://sepolia.etherscan.io/address/0x24Ef36Ec5b626D7DCD09a98F3083c2758F0F77bF) ([v0.2.3](https://github.com/iExec-Nox/nox-protocol-contracts/releases/tag/v0.2.3))
- Arbitrum Sepolia: [0xd464B198f06756a1d00be223634b85E0a731c229](https://sepolia.arbiscan.io/address/0xd464B198f06756a1d00be223634b85E0a731c229) ([v0.2.4](https://github.com/iExec-Nox/nox-protocol-contracts/releases/tag/v0.2.4))

## Extended Details

- Coverage: [app.codecov.io](https://app.codecov.io/gh/iExec-Nox/nox-protocol-contracts)
- Slither static analysis: [nox-protocol-contracts/security/code-scanning](https://github.com/iExec-Nox/nox-protocol-contracts/security/code-scanning)
