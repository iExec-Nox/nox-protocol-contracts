// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {Common} from "./Common.sol";

/**
 * @title Admin
 * @notice Role-based admin layer for NoxCompute.
 * @dev Two roles drive privileged actions:
 *      - DEFAULT_ADMIN_ROLE: grants/revokes other roles. Follows OZ AccessControlDefaultAdminRules:
 *        single holder, transferable only through the two-step beginDefaultAdminTransfer/
 *        acceptDefaultAdminTransfer flow, not grantable/revocable directly, and never
 *        renounceable (transfers to address(0) are blocked).
 *      - UPGRADER_ROLE: authorizes UUPS upgrades AND updates infrastructure config
 *        (KMS public key, gateway address, proof expiration duration).
 */
abstract contract Admin is Common, AccessControlDefaultAdminRulesUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /**
     * Sets the KMS public key used for ECIES encryption.
     * Only callable by an UPGRADER_ROLE holder.
     * @param newKmsPublicKey Compressed SEC1 secp256k1 public key (33 bytes)
     */
    function setKmsPublicKey(
        bytes calldata newKmsPublicKey
    ) external override onlyRole(UPGRADER_ROLE) {
        _setKmsPublicKey(newKmsPublicKey);
    }

    /**
     * Sets Gateway wallet address.
     * Only callable by an UPGRADER_ROLE holder.
     * @param gatewayAddress New Gateway wallet address
     */
    function setGateway(address gatewayAddress) external override onlyRole(UPGRADER_ROLE) {
        _setGateway(gatewayAddress);
    }

    /**
     * Sets the proof expiration duration.
     * Only callable by an UPGRADER_ROLE holder.
     * @param newDuration New expiration duration in seconds
     */
    function setProofExpirationDuration(
        uint256 newDuration
    ) external override onlyRole(UPGRADER_ROLE) {
        _setProofExpirationDuration(newDuration);
    }

    /**
     * Returns the KMS public key used for ECIES encryption.
     */
    function kmsPublicKey() external view override returns (bytes memory) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.kmsPublicKey;
    }

    /**
     * Returns the Gateway wallet address.
     */
    function gateway() external view override returns (address) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.gateway;
    }

    /**
     * Returns the proof expiration duration in seconds.
     */
    function proofExpirationDuration() external view override returns (uint256) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.proofExpirationDuration;
    }

    /**
     * @notice Begins the two-step transfer of DEFAULT_ADMIN_ROLE to a new admin.
     * @dev Transferring to address(0) is forbidden: it is the only path through which
     * DEFAULT_ADMIN_ROLE could be renounced (OZ only allows renouncement as the completion
     * of a pending transfer to address(0)). With no admin left, roles could never be granted
     * or revoked again, permanently freezing role management and, once no UPGRADER_ROLE
     * holder remains, protocol upgrades and infrastructure config.
     * @param newAdmin The new admin address
     */
    function beginDefaultAdminTransfer(address newAdmin) public override {
        require(newAdmin != address(0), AdminRoleRenouncementForbidden());
        super.beginDefaultAdminTransfer(newAdmin);
    }

    /**
     * Authorizes contract upgrades only by an UPGRADER_ROLE holder.
     */
    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev Initializes AccessControlDefaultAdminRules (no transfer delay) and grants
     * the defined roles.
     */
    function _initAccessControl(address admin, address upgrader) internal {
        require(admin != address(0), InvalidZeroAddress());
        require(upgrader != address(0), InvalidZeroAddress());
        __AccessControlDefaultAdminRules_init(0, admin);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @dev Validates, stores, and emits for a KMS public key update.
     * Validates the key is a well-formed compressed SEC1 secp256k1 public key:
     * - 33 bytes
     * - prefix byte is `0x02` or `0x03`
     * - X-coordinate below the field prime.
     * Note: this does not verify the X-coordinate has a corresponding point on the curve.
     */
    function _setKmsPublicKey(bytes calldata key) internal {
        require(key.length == 33, InvalidKmsPublicKeyLength());
        require(key[0] == 0x02 || key[0] == 0x03, InvalidKmsPublicKey());
        uint256 fieldPrime = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
        uint256 xCoord = uint256(bytes32(key[1:33]));
        require(xCoord < fieldPrime, InvalidKmsPublicKey());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.kmsPublicKey = key;
        emit KmsPublicKeyUpdated(key);
    }

    /**
     * @dev Validates, stores, and emits for a gateway address update.
     */
    function _setGateway(address gatewayAddress) internal {
        require(gatewayAddress != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.gateway = gatewayAddress;
        emit GatewayUpdated(gatewayAddress);
    }

    /**
     * @dev Stores and emits for a proof expiration duration update.
     */
    function _setProofExpirationDuration(uint256 newDuration) internal {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = newDuration;
        emit ProofExpirationDurationUpdated(newDuration);
    }
}
