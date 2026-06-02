# Changelog

## [0.2.3](https://github.com/iExec-Nox/nox-protocol-contracts/compare/v0.2.2...v0.2.3) (2026-06-02)

This release introduces a significant refactoring of the NoxCompute contract, now split into focused sub-modules. It also marks the first deployment of the protocol on Ethereum Sepolia.

### 🚀 Added

* Use builtin `erc7201()` for storage slot computation ([#131](https://github.com/iExec-Nox/nox-protocol-contracts/issues/131)) ([b5ae509](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b5ae509bcd7182e2c815111029746b32193cbb45))
* Add new networks (Sepolia) ([#133](https://github.com/iExec-Nox/nox-protocol-contracts/issues/133)) ([cacdd9a](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cacdd9a881c6878862c2f6583dd40d8d6c6e6918))
* Add admin access control ([#141](https://github.com/iExec-Nox/nox-protocol-contracts/issues/141)) ([cf6885c](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cf6885ca40f36e45dab0ba95ec4df7884be95d12))
* Deploy the protocol on Ethereum Sepolia ([#154](https://github.com/iExec-Nox/nox-protocol-contracts/issues/154)) ([b4e64b9](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b4e64b9e0bec91197d49b871d521bcc829a3dfd4))


### ✍️ Changed

* Split initialOwner into explicit per-role addresses ([#145](https://github.com/iExec-Nox/nox-protocol-contracts/issues/145)) ([015864d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/015864d6e4591afbc0a9207d7219afcde71255d5))
* Fix KMS public key & prepare Ethereum Sepolia deployment ([#148](https://github.com/iExec-Nox/nox-protocol-contracts/issues/148)) ([d41bac5](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d41bac58c561663a0a2e5969fef8a00353ff0db3))
* Include `select` in operations' common workflow ([#135](https://github.com/iExec-Nox/nox-protocol-contracts/issues/135)) ([648e742](https://github.com/iExec-Nox/nox-protocol-contracts/commit/648e742276e5daec4e9274ee26be3898191b7dd4))
* Make common checks as close as possible ([#130](https://github.com/iExec-Nox/nox-protocol-contracts/issues/130)) ([f936343](https://github.com/iExec-Nox/nox-protocol-contracts/commit/f93634377ce1ad3ea6769af6cc4514ffaa99ca5d))
* Merge all execute functions into a single function ([#134](https://github.com/iExec-Nox/nox-protocol-contracts/issues/134)) ([26a316d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/26a316d3eaeba3187f452039ba3100b4837ddd3d))
* Move safe functions and generate handles of all ops in the same function ([#132](https://github.com/iExec-Nox/nox-protocol-contracts/issues/132)) ([98744df](https://github.com/iExec-Nox/nox-protocol-contracts/commit/98744df0c3bdbfe9b5197cea629dd06d45e334e7))
* Split and update tests ([#137](https://github.com/iExec-Nox/nox-protocol-contracts/issues/137)) ([ccfa375](https://github.com/iExec-Nox/nox-protocol-contracts/commit/ccfa375751079d080ae55c5f9072d2902d1128ee))
* Split NoxCompute contract into sub-modules ([#136](https://github.com/iExec-Nox/nox-protocol-contracts/issues/136)) ([527cd47](https://github.com/iExec-Nox/nox-protocol-contracts/commit/527cd474e54e30150e4b72f43e95bc66e21a5d50))
* Use upgrader key ([#152](https://github.com/iExec-Nox/nox-protocol-contracts/issues/152)) ([a4d7e6a](https://github.com/iExec-Nox/nox-protocol-contracts/commit/a4d7e6ae37013b67505b5424654693514a82f540))


### 📋 Misc

* Add Sepolia network to CI workflows ([#149](https://github.com/iExec-Nox/nox-protocol-contracts/issues/149)) ([170f05d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/170f05d5b8540242026383b57390c2fe0508f4b3))
* Add Ethereum Sepolia proxy address to Nox.sol ([#155](https://github.com/iExec-Nox/nox-protocol-contracts/issues/155)) ([b97672b](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b97672b0ca274e74713cf611ddf442adaf79a8d9))
* Add Sepolia network to CI workflows ([#149](https://github.com/iExec-Nox/nox-protocol-contracts/issues/149)) ([170f05d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/170f05d5b8540242026383b57390c2fe0508f4b3))

## [0.2.2](https://github.com/iExec-Nox/nox-protocol-contracts/compare/v0.2.1...v0.2.2) (2026-04-20)


### 📋 Misc

* Include artifacts of arbitrumSepolia in npm package files ([22e2247](https://github.com/iExec-Nox/nox-protocol-contracts/commit/22e2247f53291bc5c86c2bd4be0d8ea98840eeec))

## [0.2.1](https://github.com/iExec-Nox/nox-protocol-contracts/compare/v0.2.0...v0.2.1) (2026-04-17)


### 📋 Misc

* Include `NoxCompute.sol` in npm package files ([3bc4737](https://github.com/iExec-Nox/nox-protocol-contracts/commit/3bc47377191df222e74f8dbe175e7fda8456e5cd))

## [0.2.0](https://github.com/iExec-Nox/nox-protocol-contracts/compare/v0.1.0...v0.2.0) (2026-04-16)

### 🚀 Added

* Remove eaddress leftover references ([#122](https://github.com/iExec-Nox/nox-protocol-contracts/issues/122)) ([83ccb4e](https://github.com/iExec-Nox/nox-protocol-contracts/commit/83ccb4ec152cf73f1f49d6725002168b94be815c))

### ✍️ Changed

* Emit zero handle seeds ([#119](https://github.com/iExec-Nox/nox-protocol-contracts/issues/119)) ([b3fa6f5](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b3fa6f50f7d6974465dde4711e3acd73b05e960d))

## 0.1.0 (2026-04-09)

This first release establishes the core Nox protocol contracts. It introduces the ACL system with transient and permanent permissions, the NoxCompute with a full set of confidential compute primitives (arithmetic, comparison, safe math, transfer/mint/burn), and the Solidity SDK library. Key infrastructure additions include gateway registry, UUPS upgradeability, on-chain decryption proof validation, KMS public key support, CreateX deployment, and a dual BUSL-1.1/MIT license.

---

### 🚀 Added

* Init project ([#2](https://github.com/iExec-Nox/nox-protocol-contracts/issues/2)) ([3ce81f7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/3ce81f71ffbc4c5eac13edb00735ab2f7929faa5))
* ACL initialization ([#1](https://github.com/iExec-Nox/nox-protocol-contracts/issues/1)) ([b6ca7aa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b6ca7aa863425f21ee49e74f876b7c5f1cd9d321))
* Add `allow` & `allowTransient` functions ([#4](https://github.com/iExec-Nox/nox-protocol-contracts/issues/4)) ([de24cb8](https://github.com/iExec-Nox/nox-protocol-contracts/commit/de24cb8739bdda194d750e5869043c0ae900b342))
* Init gateway registry proxy ([#5](https://github.com/iExec-Nox/nox-protocol-contracts/issues/5)) ([c0cdc19](https://github.com/iExec-Nox/nox-protocol-contracts/commit/c0cdc19a1bc7598f8f32f845f2f867db7e75bdbf))
* Add `addViewer` and `isViewer` functions to ACL ([#6](https://github.com/iExec-Nox/nox-protocol-contracts/issues/6)) ([8e03ad7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8e03ad7fa61d8c56e8ad7537d13b5023b6850845))
* Support account abstraction ([#7](https://github.com/iExec-Nox/nox-protocol-contracts/issues/7)) ([909ce48](https://github.com/iExec-Nox/nox-protocol-contracts/commit/909ce48ffdcec9a5699fc1ad6996cbccc6ac7bbf))
* Register gateway ([#8](https://github.com/iExec-Nox/nox-protocol-contracts/issues/8)) ([4b6cd1f](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4b6cd1f2ce4e54292a0eada1fe9c8298df58e66a))
* Add TEE library for confidential computations ([#9](https://github.com/iExec-Nox/nox-protocol-contracts/issues/9)) ([0f3f404](https://github.com/iExec-Nox/nox-protocol-contracts/commit/0f3f40401bf4bb55b1fc1359da7ed167becf17e0))
* Add `isPubliclyDecryptable` ([#10](https://github.com/iExec-Nox/nox-protocol-contracts/issues/10)) ([9af7f86](https://github.com/iExec-Nox/nox-protocol-contracts/commit/9af7f86e3795ba5959e357dcafda5310475645aa))
* Init TEEComputeManager contract and add proof verification function ([#11](https://github.com/iExec-Nox/nox-protocol-contracts/issues/11)) ([4592b56](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4592b5639a7abb6dc3bdc10498346e16dc8ed80e))
* Make ACL contract upgradeable with UUPS ([#12](https://github.com/iExec-Nox/nox-protocol-contracts/issues/12)) ([6014c17](https://github.com/iExec-Nox/nox-protocol-contracts/commit/6014c172e7cfb5081629218b074ab8c649916f65))
* Verify gateway signature of handle proofs ([#13](https://github.com/iExec-Nox/nox-protocol-contracts/issues/13)) ([d274788](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d2747880cd632f5bfb29b331426709961f70d5c5))
* Remove useless gateway contract ([#14](https://github.com/iExec-Nox/nox-protocol-contracts/issues/14)) ([a388aa3](https://github.com/iExec-Nox/nox-protocol-contracts/commit/a388aa39d0e8d3f91d54eff983ae90ca4f037eb5))
* Check handle type ([#15](https://github.com/iExec-Nox/nox-protocol-contracts/issues/15)) ([8117ec6](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8117ec69d83cc5ab8dfbb43f5941986df03a2916))
* Add `add` core primitive to TEEComputeManager ([#16](https://github.com/iExec-Nox/nox-protocol-contracts/issues/16)) ([61b6f3d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/61b6f3debae1c766ac1800122d2a9ed60a52650d))
* Validate chain ID in handle ([#17](https://github.com/iExec-Nox/nox-protocol-contracts/issues/17)) ([cbfa4fe](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cbfa4fe3dd0143c806ab0a68b0f8466d1170d91b))
* Add GitHub Actions deploy workflow ([#18](https://github.com/iExec-Nox/nox-protocol-contracts/issues/18)) ([1971230](https://github.com/iExec-Nox/nox-protocol-contracts/commit/197123017cef744fff447618681ca9c60199ad14))
* Transiently allow app after proof validation ([#20](https://github.com/iExec-Nox/nox-protocol-contracts/issues/20)) ([42a4f32](https://github.com/iExec-Nox/nox-protocol-contracts/commit/42a4f3279540c8b83c86c13308cb3df7bb9bdc8e))
* Add `sub`, `div` & `plaintextToEncrypted` core primitives ([#21](https://github.com/iExec-Nox/nox-protocol-contracts/issues/21)) ([8869f33](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8869f336cae6dc14e4ed2b6bbc516f5a99cad993))
* Proof v0.1 & ACL getters ([#22](https://github.com/iExec-Nox/nox-protocol-contracts/issues/22)) ([b2613c4](https://github.com/iExec-Nox/nox-protocol-contracts/commit/b2613c48cd00e71f759a35791fc37a118b66b2ab))
* Add `fromExternal`, `safeAdd`, `safeSub`, and `select` to TEEPrimitives library ([#23](https://github.com/iExec-Nox/nox-protocol-contracts/issues/23)) ([79f6598](https://github.com/iExec-Nox/nox-protocol-contracts/commit/79f6598c0d5c7400131637aa193b121129ea7692))
* Add safe math operations ([#24](https://github.com/iExec-Nox/nox-protocol-contracts/issues/24)) ([d7eef1c](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d7eef1c9d25d5df1ea19aa1dbed7519edef1918a))
* Add Solidity SDK integration tests ([#26](https://github.com/iExec-Nox/nox-protocol-contracts/issues/26)) ([1c4a07d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/1c4a07dda5b525c5b4a45ad970a4c92f2a238b67))
* Add multiplication and comparison operations to TEEComputeManager ([#27](https://github.com/iExec-Nox/nox-protocol-contracts/issues/27)) ([cd37548](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cd375480a8377310717d0d59874d2fe82ff9c714))
* Expand TEEType enum to include additional types ([#31](https://github.com/iExec-Nox/nox-protocol-contracts/issues/31)) ([67e7e84](https://github.com/iExec-Nox/nox-protocol-contracts/commit/67e7e8405e342c7a8675e4eec27a71ef3673b44f))
* Implement batch permission check in ACL and TEEComputeManager ([#33](https://github.com/iExec-Nox/nox-protocol-contracts/issues/33)) ([65acda4](https://github.com/iExec-Nox/nox-protocol-contracts/commit/65acda404bb9ab1eda9f2cf80e0f060dff514722))
* Add proof expiration duration to TEEComputeManager ([#34](https://github.com/iExec-Nox/nox-protocol-contracts/issues/34)) ([065dfd5](https://github.com/iExec-Nox/nox-protocol-contracts/commit/065dfd52c56d08aa5499a15469a8c98cbb2864ff))
* Use `select` in mock token ([#35](https://github.com/iExec-Nox/nox-protocol-contracts/issues/35)) ([d84b0e5](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d84b0e595a06d1b882cfae5b0a34d1792561ba0e))
* CreateX deployment ([#36](https://github.com/iExec-Nox/nox-protocol-contracts/issues/36)) ([985a004](https://github.com/iExec-Nox/nox-protocol-contracts/commit/985a00408750474eb626848b116a4f3b1b080a3b))
* Add missing TEEPrimitives in Solidity library with tests ([#37](https://github.com/iExec-Nox/nox-protocol-contracts/issues/37)) ([cec9afa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/cec9afa79845a455ef06da8cb97012c3b379fad3))
* Add set-gateway script and GitHub Actions workflow ([#38](https://github.com/iExec-Nox/nox-protocol-contracts/issues/38)) ([7f36f54](https://github.com/iExec-Nox/nox-protocol-contracts/commit/7f36f545be413309e22c172f40750f1174417bff))
* Add support for `euint16` type in Nox library ([#45](https://github.com/iExec-Nox/nox-protocol-contracts/issues/45)) ([791afc7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/791afc721aba3862ce1c8f95346ef155f3121f10))
* Add support for `eint16` and `eint256` types in Nox Lib ([#46](https://github.com/iExec-Nox/nox-protocol-contracts/issues/46)) ([940463a](https://github.com/iExec-Nox/nox-protocol-contracts/commit/940463aef9b45ef6c808f49296c07013b669368c))
* Add KMS public key ([#48](https://github.com/iExec-Nox/nox-protocol-contracts/issues/48)) ([615aafe](https://github.com/iExec-Nox/nox-protocol-contracts/commit/615aafe304ea2bb2043ff2431b0b6cb29f450e32))
* Add upgrade scripts ([#50](https://github.com/iExec-Nox/nox-protocol-contracts/issues/50)) ([6089545](https://github.com/iExec-Nox/nox-protocol-contracts/commit/60895453c9bbee85768bf6e79640c46344cae10e))
* Add advanced functions to SDK lib ([#53](https://github.com/iExec-Nox/nox-protocol-contracts/issues/53)) ([653dafa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/653dafa9bf7c797ac8caa9e5f24de0c666decc93))
* Add comparison functions to SDK lib ([#54](https://github.com/iExec-Nox/nox-protocol-contracts/issues/54)) ([4b40978](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4b409780b8bf29239a1af0a544129dd181debc30))
* Implement transfer, mint, and burn functions in NoxCompute ([#44](https://github.com/iExec-Nox/nox-protocol-contracts/issues/44)) ([4f9f9ac](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4f9f9ac68aee8dff8805c97968e2f9e761c9b0a8))
* Upgrade Solidity to 0.8.34 and enable viaIR optimizer ([#64](https://github.com/iExec-Nox/nox-protocol-contracts/issues/64)) ([bdcbbac](https://github.com/iExec-Nox/nox-protocol-contracts/commit/bdcbbacbe93e0c66c35af96f4707e1996e43a6de))
* Implement `safeMul` and `safeDiv` functions in NoxCompute ([#73](https://github.com/iExec-Nox/nox-protocol-contracts/issues/73)) ([6a210ec](https://github.com/iExec-Nox/nox-protocol-contracts/commit/6a210ec950e46509400e55b42578256b5bb29f0c))
* Remove public functions from SDK library ([#76](https://github.com/iExec-Nox/nox-protocol-contracts/issues/76)) ([f4b96f8](https://github.com/iExec-Nox/nox-protocol-contracts/commit/f4b96f829a8ea68b86a438f03fe230f8b6ff1e84))
* Add on-chain decryption proof validation ([#80](https://github.com/iExec-Nox/nox-protocol-contracts/issues/80)) ([c7c5fca](https://github.com/iExec-Nox/nox-protocol-contracts/commit/c7c5fca31e4bce2a89f255d1c4e55f6f3695492b))
* Add verification ([#81](https://github.com/iExec-Nox/nox-protocol-contracts/issues/81)) ([f60bc5d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/f60bc5d27bcf69caf2a11ef18d9d667f67cddc93))
* Handle v2 with new field attribute ([#82](https://github.com/iExec-Nox/nox-protocol-contracts/issues/82)) ([3a69cf4](https://github.com/iExec-Nox/nox-protocol-contracts/commit/3a69cf44c1dfc4105b2ad94da925ec9d61ee94cd))
* Add `disallowTransient` function ([#89](https://github.com/iExec-Nox/nox-protocol-contracts/issues/89)) ([85a228d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/85a228da133c6ae3d1531cc3cf43d8dc2c620e51))
* Migrate OpenZeppelin Hardhat upgrades ([#93](https://github.com/iExec-Nox/nox-protocol-contracts/issues/93)) ([1833900](https://github.com/iExec-Nox/nox-protocol-contracts/commit/183390009158bb7d636a71bad86adadf62f09e47))
* Rename `uniqSeed` to `uniqueSeed` ([#95](https://github.com/iExec-Nox/nox-protocol-contracts/issues/95)) ([5424f74](https://github.com/iExec-Nox/nox-protocol-contracts/commit/5424f74ef3b7727ebf15fc3fa042bc4a8e3169e9))
* Restrict arithmetic types to only supported types ([#100](https://github.com/iExec-Nox/nox-protocol-contracts/issues/100)) ([46f3032](https://github.com/iExec-Nox/nox-protocol-contracts/commit/46f3032c3016da78ff19d6f0edf96febdc844ad9))
* Resolve null handles in SDK ([#102](https://github.com/iExec-Nox/nox-protocol-contracts/issues/102)) ([c6cf37b](https://github.com/iExec-Nox/nox-protocol-contracts/commit/c6cf37bb7462dfd306fe9e5f5ec1f716ef6a4ea8))
* Support raw non ABI-encoded data in public decryption ([#103](https://github.com/iExec-Nox/nox-protocol-contracts/issues/103)) ([4f9b9b3](https://github.com/iExec-Nox/nox-protocol-contracts/commit/4f9b9b36106d861d163685b72a5b01480828d521))

### ✍️ Changed

* Update deployment job dependencies and package manager version ([#19](https://github.com/iExec-Nox/nox-protocol-contracts/issues/19)) ([0128823](https://github.com/iExec-Nox/nox-protocol-contracts/commit/0128823d9a17deaa6c213b14b8c96b3fdcadf5b9))
* Refactor `TEEComputeManager` to use immutable ACL address ([#25](https://github.com/iExec-Nox/nox-protocol-contracts/issues/25)) ([210a943](https://github.com/iExec-Nox/nox-protocol-contracts/commit/210a9432eeafdfc268c04cb9b75bc5cca4643bac))
* Refactor tests ([#30](https://github.com/iExec-Nox/nox-protocol-contracts/issues/30)) ([fe34fae](https://github.com/iExec-Nox/nox-protocol-contracts/commit/fe34faebd49f46a40fbd550ad020b265c52c3bfc))
* Rename `contracts/lib/TEEPrimitives` to `contracts/sdk/Nox.sol` ([#41](https://github.com/iExec-Nox/nox-protocol-contracts/issues/41)) ([5eb6f0c](https://github.com/iExec-Nox/nox-protocol-contracts/commit/5eb6f0c30de85d363326d99611c1e1a18e9fdcd3))
* Rename `TEEComputeManager` to `NoxCompute` ([#42](https://github.com/iExec-Nox/nox-protocol-contracts/issues/42)) ([5bdab03](https://github.com/iExec-Nox/nox-protocol-contracts/commit/5bdab036fb9e0f4e7634ebad5e108d5397fd2f53))
* Use generic bytes32 type in `plaintextToEncrypted` ([#43](https://github.com/iExec-Nox/nox-protocol-contracts/issues/43)) ([1885c17](https://github.com/iExec-Nox/nox-protocol-contracts/commit/1885c17c3dc4d545525d4fcc3d6987fef9987e61))
* Update CREATE2 deployment salt ([#49](https://github.com/iExec-Nox/nox-protocol-contracts/issues/49)) ([3a99104](https://github.com/iExec-Nox/nox-protocol-contracts/commit/3a99104f6fb7d71addbc4d2e3f9c26b0a14d5145))
* Nox lib address resolution ([#55](https://github.com/iExec-Nox/nox-protocol-contracts/issues/55)) ([856b84a](https://github.com/iExec-Nox/nox-protocol-contracts/commit/856b84a802385020a459f40cc35beed7fa2c5522))
* Revert with `UninitializedHandle` custom error in Nox lib ([#57](https://github.com/iExec-Nox/nox-protocol-contracts/issues/57)) ([1110701](https://github.com/iExec-Nox/nox-protocol-contracts/commit/11107017cc1213c963067fc40b9f6a9ff362a735))
* Merge `NoxCompute` and `ACL` contracts ([#58](https://github.com/iExec-Nox/nox-protocol-contracts/issues/58)) ([48c0635](https://github.com/iExec-Nox/nox-protocol-contracts/commit/48c0635d0f522aa178e7ac5534cce6078e5b6daa))
* Reorder NoxCompute functions and clean soldoc ([#65](https://github.com/iExec-Nox/nox-protocol-contracts/issues/65)) ([9b01693](https://github.com/iExec-Nox/nox-protocol-contracts/commit/9b01693c9d3c37bd1a9a67b86d2c3c1312965a3e))
* Use non-upgradeable EIP712 and replace if-revert with require ([#66](https://github.com/iExec-Nox/nox-protocol-contracts/issues/66)) ([f055755](https://github.com/iExec-Nox/nox-protocol-contracts/commit/f055755054f45d14181406d3e71c60e09adf59ed))
* Optimize handle generation code ([#68](https://github.com/iExec-Nox/nox-protocol-contracts/issues/68)) ([af0f077](https://github.com/iExec-Nox/nox-protocol-contracts/commit/af0f0776b78c8327ba8a8b2a319f4c1d48b74346))
* Rename compute function ([#72](https://github.com/iExec-Nox/nox-protocol-contracts/issues/72)) ([97284a1](https://github.com/iExec-Nox/nox-protocol-contracts/commit/97284a18c7b25ddf8916a8dd86ee8aeaabdbdc9b))
* Mark functions as view ([#85](https://github.com/iExec-Nox/nox-protocol-contracts/issues/85)) ([a4d4926](https://github.com/iExec-Nox/nox-protocol-contracts/commit/a4d4926756494684040256c16ad1b095ab873cae))
* Compact decryption proof format ([#87](https://github.com/iExec-Nox/nox-protocol-contracts/issues/87)) ([0ebd905](https://github.com/iExec-Nox/nox-protocol-contracts/commit/0ebd905218097721c6b511ce281d6c8ba9b3592a))
* Clean `validateDecryptionProof` function ([#88](https://github.com/iExec-Nox/nox-protocol-contracts/issues/88)) ([73359fc](https://github.com/iExec-Nox/nox-protocol-contracts/commit/73359fc4763474233994b3e3a81ef1d9a45524b8))
* Add option to CI ([#90](https://github.com/iExec-Nox/nox-protocol-contracts/issues/90)) ([da0e8c2](https://github.com/iExec-Nox/nox-protocol-contracts/commit/da0e8c2c2578f7859b19e7ce9d8befbd5344dd27))
* Review comments from #93 ([#99](https://github.com/iExec-Nox/nox-protocol-contracts/issues/99)) ([59a0c0e](https://github.com/iExec-Nox/nox-protocol-contracts/commit/59a0c0e690f0ec4d67c3fb1c52b11a669614f5d6))
* Gas stats report script ([#101](https://github.com/iExec-Nox/nox-protocol-contracts/issues/101)) ([7624de7](https://github.com/iExec-Nox/nox-protocol-contracts/commit/7624de70491db74a2349be67f2a21f1ca0bba3ac))
* Fix upgrade script ([#109](https://github.com/iExec-Nox/nox-protocol-contracts/issues/109)) ([0be7079](https://github.com/iExec-Nox/nox-protocol-contracts/commit/0be7079feed03ddc8793215975cf3fb20ab2263d))
* Push upgrade artifacts from CI ([#110](https://github.com/iExec-Nox/nox-protocol-contracts/issues/110)) ([8ad27aa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/8ad27aa795fe3ecdbf92941fcfb686a50a7963bd))
* Refactor TypeUtils and fix coverage ([#114](https://github.com/iExec-Nox/nox-protocol-contracts/issues/114)) ([6f1271d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/6f1271d5d0607cf31971b13a1e1b94460fa3ef5f))

### 📋 Misc

* Enhance npm security settings ([#67](https://github.com/iExec-Nox/nox-protocol-contracts/issues/67)) ([163bc4d](https://github.com/iExec-Nox/nox-protocol-contracts/commit/163bc4d3b9ff750149c4916face824719cb4c71d))
* Update ArbitrumSepolia config ([#69](https://github.com/iExec-Nox/nox-protocol-contracts/issues/69)) ([823e6c3](https://github.com/iExec-Nox/nox-protocol-contracts/commit/823e6c3a6bd7c7ba83122b56b39733d374b60b8d))
* Push artifacts on the protected branch ([#70](https://github.com/iExec-Nox/nox-protocol-contracts/issues/70)) ([882d307](https://github.com/iExec-Nox/nox-protocol-contracts/commit/882d30705d7bd78a0e9168e9b4252b86004209ec))
* Automatically test new operations ([#75](https://github.com/iExec-Nox/nox-protocol-contracts/issues/75)) ([ef1e154](https://github.com/iExec-Nox/nox-protocol-contracts/commit/ef1e1544aaa71ba0504cee0a11b26614905d66c1))
* Upgrade OZ dependencies ([#78](https://github.com/iExec-Nox/nox-protocol-contracts/issues/78)) ([536f745](https://github.com/iExec-Nox/nox-protocol-contracts/commit/536f745a3a5f2a8490d37f2fb89af53be705e86e))
* Add dual-license setup (BUSL-1.1 / MIT) ([#96](https://github.com/iExec-Nox/nox-protocol-contracts/issues/96)) ([c932ffa](https://github.com/iExec-Nox/nox-protocol-contracts/commit/c932ffa944c6cccb35f3b316d9f74250aecec85b))
* Clean license check ([#97](https://github.com/iExec-Nox/nox-protocol-contracts/issues/97)) ([49b1201](https://github.com/iExec-Nox/nox-protocol-contracts/commit/49b12015635e83a71ce05ff25121974df96d46af))
* Prerequisites for local stack ([#104](https://github.com/iExec-Nox/nox-protocol-contracts/issues/104)) ([04b83de](https://github.com/iExec-Nox/nox-protocol-contracts/commit/04b83de11aab80b69a04bbc0e4d7a78110b9d851))
* Register manifest files for deployed proxies ([#106](https://github.com/iExec-Nox/nox-protocol-contracts/issues/106)) ([d27a495](https://github.com/iExec-Nox/nox-protocol-contracts/commit/d27a4958c8421e6cfb975d206589bcd2ff517fbd))
* Update dependencies & readme ([#107](https://github.com/iExec-Nox/nox-protocol-contracts/issues/107)) ([a80e5f0](https://github.com/iExec-Nox/nox-protocol-contracts/commit/a80e5f0138af5f806a7f7da9482e975af4b6626a))
* Fix upgrade manifests ([#108](https://github.com/iExec-Nox/nox-protocol-contracts/issues/108)) ([66b0a9e](https://github.com/iExec-Nox/nox-protocol-contracts/commit/66b0a9ecb97a09dee06265fe954d5250d8ff9a79))
