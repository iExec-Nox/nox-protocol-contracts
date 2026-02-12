# Changelog

## 1.0.0 (2026-02-12)


### 🚀 Added

* ACL initialization ([#1](https://github.com/iExec-Nox/nox-protocol-contracts/issues/1)) ([b6ca7aa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b6ca7aa863425f21ee49e74f876b7c5f1cd9d321))
* Add `add` core primitives to TEEComputeManager ([#16](https://github.com/iExec-Nox/nox-protocol-contracts/issues/16)) ([61b6f3d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/61b6f3debae1c766ac1800122d2a9ed60a52650d))
* add `addViewer` and `isViewer` functions to ACL ([#6](https://github.com/iExec-Nox/nox-protocol-contracts/issues/6)) ([8e03ad7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8e03ad7fa61d8c56e8ad7537d13b5023b6850845))
* Add `allow` & `allowTransient` functions ([#4](https://github.com/iExec-Nox/nox-protocol-contracts/issues/4)) ([de24cb8](https://github.com/iExec-Nox/nox-protocol-contracts/commit/de24cb8739bdda194d750e5869043c0ae900b342))
* Add `fromExternal`, `safeAdd`, `safeSub`, and `select` to TEEPrimitives library ([#23](https://github.com/iExec-Nox/nox-protocol-contracts/issues/23)) ([79f6598](https://github.com/iExec-Nox/nox-protocol-contracts/commit/79f6598c0d5c7400131637aa193b121129ea7692))
* Add `isPubliclyDecryptable` ([#10](https://github.com/iExec-Nox/nox-protocol-contracts/issues/10)) ([9af7f86](https://github.com/iExec-Nox/nox-protocol-contracts/commit/9af7f86e3795ba5959e357dcafda5310475645aa))
* Add `sub`, `div` & `plaintextToEncrypted` core primitive ([#21](https://github.com/iExec-Nox/nox-protocol-contracts/issues/21)) ([8869f33](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8869f336cae6dc14e4ed2b6bbc516f5a99cad993))
* Add GitHub Actions deploy workflow ([#18](https://github.com/iExec-Nox/nox-protocol-contracts/issues/18)) ([1971230](https://github.com/iExec-Nox/nox-protocol-contracts/commit/197123017cef744fff447618681ca9c60199ad14))
* Add missing TEEPrimitives in solidity library and cover them in tests ([#37](https://github.com/iExec-Nox/nox-protocol-contracts/issues/37)) ([cec9afa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cec9afa79845a455ef06da8cb97012c3b379fad3))
* add multiplication and comparison operations to TEEComputeManager ([#27](https://github.com/iExec-Nox/nox-protocol-contracts/issues/27)) ([cd37548](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cd375480a8377310717d0d59874d2fe82ff9c714))
* add proof expiration duration to TEEComputeManager ([#34](https://github.com/iExec-Nox/nox-protocol-contracts/issues/34)) ([065dfd5](https://github.com/iExec-Nox/nox-protocol-contracts/commit/065dfd52c56d08aa5499a15469a8c98cbb2864ff))
* add safeMath operations ([#24](https://github.com/iExec-Nox/nox-protocol-contracts/issues/24)) ([d7eef1c](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d7eef1c9d25d5df1ea19aa1dbed7519edef1918a))
* add set-gateway script and github action workflow ([#38](https://github.com/iExec-Nox/nox-protocol-contracts/issues/38)) ([7f36f54](https://github.com/iExec-Nox/nox-protocol-contracts/commit/7f36f545be413309e22c172f40750f1174417bff))
* Add support for `euint16` type in Nox library ([#45](https://github.com/iExec-Nox/nox-protocol-contracts/issues/45)) ([791afc7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/791afc721aba3862ce1c8f95346ef155f3121f10))
* Add TEE library for confidential computations ([#9](https://github.com/iExec-Nox/nox-protocol-contracts/issues/9)) ([0f3f404](https://github.com/iExec-Nox/nox-protocol-contracts/commit/0f3f40401bf4bb55b1fc1359da7ed167becf17e0))
* Check handle type ([#15](https://github.com/iExec-Nox/nox-protocol-contracts/issues/15)) ([8117ec6](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8117ec69d83cc5ab8dfbb43f5941986df03a2916))
* createx deployment ([#36](https://github.com/iExec-Nox/nox-protocol-contracts/issues/36)) ([985a004](https://github.com/iExec-Nox/nox-protocol-contracts/commit/985a00408750474eb626848b116a4f3b1b080a3b))
* expand TEEType enum to include additional types ([#31](https://github.com/iExec-Nox/nox-protocol-contracts/issues/31)) ([67e7e84](https://github.com/iExec-Nox/nox-protocol-contracts/commit/67e7e8405e342c7a8675e4eec27a71ef3673b44f))
* implement batch permission check in ACL and TEEComputeManager ([#33](https://github.com/iExec-Nox/nox-protocol-contracts/issues/33)) ([65acda4](https://github.com/iExec-Nox/nox-protocol-contracts/commit/65acda404bb9ab1eda9f2cf80e0f060dff514722))
* Init gateway registry proxy ([#5](https://github.com/iExec-Nox/nox-protocol-contracts/issues/5)) ([c0cdc19](https://github.com/iExec-Nox/nox-protocol-contracts/commit/c0cdc19a1bc7598f8f32f845f2f867db7e75bdbf))
* Init TEEComputeManager contract and add proof verification function ([#11](https://github.com/iExec-Nox/nox-protocol-contracts/issues/11)) ([4592b56](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4592b5639a7abb6dc3bdc10498346e16dc8ed80e))
* Make ACL contract upgradable with `UUPS` ([#12](https://github.com/iExec-Nox/nox-protocol-contracts/issues/12)) ([6014c17](https://github.com/iExec-Nox/nox-protocol-contracts/commit/6014c172e7cfb5081629218b074ab8c649916f65))
* Proof v0.1 & ACL getters ([#22](https://github.com/iExec-Nox/nox-protocol-contracts/issues/22)) ([b2613c4](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b2613c48cd00e71f759a35791fc37a118b66b2ab))
* Refactor `TEEComputeManager` to use immutable ACL address ([#25](https://github.com/iExec-Nox/nox-protocol-contracts/issues/25)) ([210a943](https://github.com/iExec-Nox/nox-protocol-contracts/commit/210a9432eeafdfc268c04cb9b75bc5cca4643bac))
* refactor tests ([#30](https://github.com/iExec-Nox/nox-protocol-contracts/issues/30)) ([fe34fae](https://github.com/iExec-Nox/nox-protocol-contracts/commit/fe34faebd49f46a40fbd550ad020b265c52c3bfc))
* Register gateway ([#8](https://github.com/iExec-Nox/nox-protocol-contracts/issues/8)) ([4b6cd1f](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4b6cd1f2ce4e54292a0eada1fe9c8298df58e66a))
* Remove useless gateway contract ([#14](https://github.com/iExec-Nox/nox-protocol-contracts/issues/14)) ([a388aa3](https://github.com/iExec-Nox/nox-protocol-contracts/commit/a388aa39d0e8d3f91d54eff983ae90ca4f037eb5))
* support account abstraction ([#7](https://github.com/iExec-Nox/nox-protocol-contracts/issues/7)) ([909ce48](https://github.com/iExec-Nox/nox-protocol-contracts/commit/909ce48ffdcec9a5699fc1ad6996cbccc6ac7bbf))
* Transiently allow app after proof validation ([#20](https://github.com/iExec-Nox/nox-protocol-contracts/issues/20)) ([42a4f32](https://github.com/iExec-Nox/nox-protocol-contracts/commit/42a4f3279540c8b83c86c13308cb3df7bb9bdc8e))
* Use select in mock token ([#35](https://github.com/iExec-Nox/nox-protocol-contracts/issues/35)) ([d84b0e5](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d84b0e595a06d1b882cfae5b0a34d1792561ba0e))
* Validate chain id in handle ([#17](https://github.com/iExec-Nox/nox-protocol-contracts/issues/17)) ([cbfa4fe](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cbfa4fe3dd0143c806ab0a68b0f8466d1170d91b))
* Verify gateway signature of handle proofs ([#13](https://github.com/iExec-Nox/nox-protocol-contracts/issues/13)) ([d274788](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d2747880cd632f5bfb29b331426709961f70d5c5))


### ✍️ Changed

* Rename `contracts/lib/TEEPrimitives` to `contracts/sdk/Nox.sol` ([#41](https://github.com/iExec-Nox/nox-protocol-contracts/issues/41)) ([5eb6f0c](https://github.com/iExec-Nox/nox-protocol-contracts/commit/5eb6f0c30de85d363326d99611c1e1a18e9fdcd3))
* Rename `TEECompteManager` to `NoxCompute` ([#42](https://github.com/iExec-Nox/nox-protocol-contracts/issues/42)) ([5bdab03](https://github.com/iExec-Nox/nox-protocol-contracts/commit/5bdab036fb9e0f4e7634ebad5e108d5397fd2f53))
* Update deployment job dependencies and package manager version ([#19](https://github.com/iExec-Nox/nox-protocol-contracts/issues/19)) ([0128823](https://github.com/iExec-Nox/nox-protocol-contracts/commit/0128823d9a17deaa6c213b14b8c96b3fdcadf5b9))
* Use generic bytes32 type in `plaintextToEncrypted` ([#43](https://github.com/iExec-Nox/nox-protocol-contracts/issues/43)) ([1885c17](https://github.com/iExec-Nox/nox-protocol-contracts/commit/1885c17c3dc4d545525d4fcc3d6987fef9987e61))


### 📋 Misc

* Add solidity SDK integration tests ([#26](https://github.com/iExec-Nox/nox-protocol-contracts/issues/26)) ([1c4a07d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/1c4a07dda5b525c5b4a45ad970a4c92f2a238b67))
* Init project ([#2](https://github.com/iExec-Nox/nox-protocol-contracts/issues/2)) ([3ce81f7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/3ce81f71ffbc4c5eac13edb00735ab2f7929faa5))
