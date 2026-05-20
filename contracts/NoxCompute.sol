// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Admin} from "./modules/Admin.sol";
import {ACL} from "./modules/ACL.sol";
import {Compute} from "./modules/Compute.sol";

/**
 * @title NoxCompute
 * @notice The entry point contract for the Nox TEE compute protocol.
 * It's role includes:
 * - Managing the access control list (ACL) for encrypted handles
 * - Validating handle proofs issued by a trusted gateway
 * - Wrapping plaintext values into public handles
 * - Triggering off-chain TEE computations through event emissions
 */
contract NoxCompute is Admin, ACL, Compute {
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() EIP712("NoxCompute", "1") {
        _disableInitializers();
    }

    /**
     * Initializes the proxy contract state.
     * @param initialOwner Initial owner address
     * @param kmsPublicKey_ KMS public key for ECIES encryption
     */
    function initialize(address initialOwner, bytes calldata kmsPublicKey_) public initializer {
        require(kmsPublicKey_.length != 0, InvalidEmptyBytes());
        __Ownable_init(initialOwner);
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = 1 hours;
        $.kmsPublicKey = kmsPublicKey_;
        _emitZeroHandleSeeds();
    }

    /**
     * @notice Initializer of 0.1.1 upgrade for already deployed proxies.
     * @notice Emits zero handle seeds for existing proxies.
     * @dev The same logic is also called in `initialize()` for fresh deployments.
     * @dev The call to this function does not need to be protected because it does
     * not do any critical operations.
     */
    function initializeV2() public reinitializer(2) {
        _emitZeroHandleSeeds();
    }
}
