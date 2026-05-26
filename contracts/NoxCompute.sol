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
     * Initializes the proxy contract state.
     * @dev Role setup is performed in `initializeV3` (called separately at deploy time
     * for fresh proxies and as part of the upgrade flow for existing ones).
     * @param kmsPublicKey_ KMS public key for ECIES encryption
     */
    function initialize(bytes calldata kmsPublicKey_) public initializer {
        require(kmsPublicKey_.length != 0, InvalidEmptyBytes());
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
     * @notice V3 reinitializer migrating the contract from `OwnableUpgradeable` to
     * `AccessControlUpgradeable`. Sets up the three roles and clears the legacy
     * Ownable storage slot.
     * @dev Must be called once per proxy:
     *      - on a fresh deployment, right after `initialize`;
     *      - on an existing V2 proxy, as part of the upgrade transaction.
     * @param admin Address granted `DEFAULT_ADMIN_ROLE` (usually a multisig).
     * @param upgrader Address granted `UPGRADER_ROLE` (CI/CD key for upgrades and
     *        infra config: KMS public key, gateway address, proof expiration).
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
     * (ERC-7201 location for `openzeppelin.storage.Ownable`). Idempotent: writing 0
     * costs only the warm-write surcharge and is safe on fresh deployments.
     */
    function _clearOwnableStorage() private {
        // bytes32(uint256(keccak256("openzeppelin.storage.Ownable")) - 1) & ~bytes32(uint256(0xff))
        bytes32 slot = 0x9016d09d72d40fdae2fd8ceac6b6234c7706214fd39c1cd1e609a0528c199300;
        assembly {
            sstore(slot, 0)
        }
    }
}
