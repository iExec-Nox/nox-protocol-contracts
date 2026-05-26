// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Admin} from "./modules/Admin.sol";
import {ACL} from "./modules/ACL.sol";
import {Compute} from "./modules/Compute.sol";
import {Sponsorship} from "./modules/Sponsorship.sol";
import {Payment} from "./modules/Payment.sol";

/**
 * @title NoxCompute
 * @notice The entry point contract for the Nox TEE compute protocol.
 * It's role includes:
 * - Managing the access control list (ACL) for encrypted handles
 * - Validating handle proofs issued by a trusted gateway
 * - Wrapping plaintext values into public handles
 * - Triggering off-chain TEE computations through event emissions
 */
contract NoxCompute is Admin, ACL, Compute, Sponsorship, Payment {
    /**
     * @dev Set cuPerOperation to 0 to disable payment.
     * @param cuPerOperation Number of Compute Units (CU) to charge per operation.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(uint8 cuPerOperation) EIP712("NoxCompute", "1") Payment(cuPerOperation) {
        _disableInitializers();
    }

    /**
     * Initializes the proxy contract state for a fresh deployment.
     * @param admin Address granted `DEFAULT_ADMIN_ROLE`.
     * @param upgrader Address granted `UPGRADER_ROLE`.
     * @param paymentManager Address granted `PAYMENT_MANAGER_ROLE`.
     * @param kmsPublicKey_ KMS public key for ECIES encryption.
     */
    function initialize(
        address admin,
        address upgrader,
        address paymentManager,
        bytes calldata kmsPublicKey_
    ) public initializer {
        require(admin != address(0), InvalidZeroAddress());
        require(upgrader != address(0), InvalidZeroAddress());
        require(paymentManager != address(0), InvalidZeroAddress());
        require(kmsPublicKey_.length != 0, InvalidEmptyBytes());
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(PAYMENT_MANAGER_ROLE, paymentManager);
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

    /**
     * @notice Initializer of 0.3.0 upgrade for already deployed proxies.
     * @notice Migrates the contract from `OwnableUpgradeable` to `AccessControlUpgradeable`:
     * initializes AccessControl, grants the three roles, and clears the legacy Ownable storage slot.
     * @param admin Address granted `DEFAULT_ADMIN_ROLE`.
     * @param upgrader Address granted `UPGRADER_ROLE`.
     * @param paymentManager Address granted `PAYMENT_MANAGER_ROLE`.
     */
    function initializeV3(
        address admin,
        address upgrader,
        address paymentManager
    ) public reinitializer(3) {
        require(admin != address(0), InvalidZeroAddress());
        require(upgrader != address(0), InvalidZeroAddress());
        require(paymentManager != address(0), InvalidZeroAddress());
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(PAYMENT_MANAGER_ROLE, paymentManager);
        _clearOwnableStorage();
    }

    /**
     * @dev Clears the slot where `OwnableUpgradeable` stored the previous `_owner`
     * (ERC-7201 location for `openzeppelin.storage.Ownable`).
     */
    function _clearOwnableStorage() private {
        // TODO: remove `slither-disable-next-line` once Slither supports the `erc7201` builtin (added in solc 0.8.35).
        // slither-disable-next-line uninitialized-state
        bytes32 slot = bytes32(erc7201("openzeppelin.storage.Ownable"));
        assembly {
            sstore(slot, 0)
        }
    }
}
