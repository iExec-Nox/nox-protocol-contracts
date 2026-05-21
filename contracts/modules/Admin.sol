// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Common} from "./Common.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Admin
 * @notice Role-based admin layer for NoxCompute.
 * @dev Three roles drive privileged actions:
 *      - DEFAULT_ADMIN_ROLE: grants/revokes other roles (multisig).
 *      - UPGRADER_ROLE: authorizes UUPS upgrades AND updates infrastructure config
 *        (KMS public key, gateway address, proof expiration duration). Held by the
 *        CI/CD pipeline key — both the upgrade transaction and the post-upgrade
 *        config tuning are driven from the same automation, so they share a single
 *        role rather than being split between distinct keys.
 *      - PAYMENT_MANAGER_ROLE: provisions, renews, revokes, and links licenses.
 */
abstract contract Admin is Common, AccessControlUpgradeable, UUPSUpgradeable {
    /// @notice Role allowed to upgrade the proxy and to tune infrastructure config.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Role allowed to manage licenses (provision, renew, revoke, link apps).
    bytes32 public constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");

    /**
     * @dev Validates the common license inputs: non-zero owner, future expiration date,
     * and non-zero monthly quota.
     */
    modifier validLicenseParams(address owner, uint32 expirationDate, uint24 monthlyQuota) {
        require(owner != address(0), InvalidZeroAddress());
        require(expirationDate > block.timestamp, InvalidExpirationDate());
        require(monthlyQuota != 0, InvalidMonthlyQuota());
        _;
    }

    /**
     * Sets the KMS public key used for ECIES encryption.
     * Only callable by an UPGRADER_ROLE holder.
     * @param newKmsPublicKey Compressed SEC1 secp256k1 public key (33 bytes)
     */
    function setKmsPublicKey(
        bytes calldata newKmsPublicKey
    ) external override onlyRole(UPGRADER_ROLE) {
        require(newKmsPublicKey.length != 0, InvalidEmptyBytes());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.kmsPublicKey = newKmsPublicKey;
        emit KmsPublicKeyUpdated(newKmsPublicKey);
    }

    /**
     * Sets Gateway wallet address.
     * Only callable by an UPGRADER_ROLE holder.
     * @param gatewayAddress New Gateway wallet address
     */
    function setGateway(address gatewayAddress) external override onlyRole(UPGRADER_ROLE) {
        require(gatewayAddress != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.gateway = gatewayAddress;
        emit GatewayUpdated(gatewayAddress);
    }

    /**
     * Sets the proof expiration duration.
     * Only callable by an UPGRADER_ROLE holder.
     * @param newDuration New expiration duration in seconds
     */
    function setProofExpirationDuration(
        uint256 newDuration
    ) external override onlyRole(UPGRADER_ROLE) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = newDuration;
        emit ProofExpirationDurationUpdated(newDuration);
    }

    /// @inheritdoc INoxCompute
    function createLicense(
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    )
        external
        override
        onlyRole(PAYMENT_MANAGER_ROLE)
        validLicenseParams(licenseOwner, expirationDate, monthlyQuota)
    {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        license.expirationDate = expirationDate;
        license.monthlyQuota = monthlyQuota;
        emit LicenseSet(licenseOwner, expirationDate, monthlyQuota);
    }

    /// @inheritdoc INoxCompute
    function renewLicense(
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    )
        external
        override
        onlyRole(PAYMENT_MANAGER_ROLE)
        validLicenseParams(licenseOwner, expirationDate, monthlyQuota)
    {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        require(expirationDate > license.expirationDate, InvalidExpirationDate());
        license.expirationDate = expirationDate;
        license.monthlyQuota = monthlyQuota;
        // consumedQuota is intentionally NOT reset: the new monthlyQuota only applies starting
        // at next month's lazy reset, the current-month usage carries over.
        emit LicenseSet(licenseOwner, expirationDate, monthlyQuota);
    }

    /// @inheritdoc INoxCompute
    function revokeLicense(address licenseOwner) external override onlyRole(PAYMENT_MANAGER_ROLE) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        require(license.expirationDate != 0, LicenseNotFound(licenseOwner));
        delete $.licenses[licenseOwner];
        emit LicenseRevoked(licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function addAppToLicense(
        address app,
        address licenseOwner
    ) external override onlyRole(PAYMENT_MANAGER_ROLE) {
        _addAppToLicense(app, licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function addAppToLicense(address app) external override {
        _addAppToLicense(app, msg.sender);
    }

    /// @inheritdoc INoxCompute
    function removeAppFromLicense(
        address app,
        address licenseOwner
    ) external override onlyRole(PAYMENT_MANAGER_ROLE) {
        _removeAppFromLicense(app, licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function removeAppFromLicense(address app) external override {
        // The link check inside _removeAppFromLicense (appLicensors[app] == msg.sender)
        // implicitly enforces that the caller owns the link being removed.
        _removeAppFromLicense(app, msg.sender);
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
     * Authorizes contract upgrades only by an UPGRADER_ROLE holder.
     */
    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Internal helper that links an app to a license owner. The owner must
     * hold an active license (non-expired, non-zero monthly quota). Emits AppAddedToLicense.
     */
    function _addAppToLicense(address app, address licenseOwner) private {
        require(app != address(0), InvalidZeroAddress());
        require(licenseOwner != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        require(
            license.expirationDate > block.timestamp && license.monthlyQuota > 0,
            LicenseOwnerHasNoLicense(licenseOwner)
        );
        $.appLicensors[app] = licenseOwner;
        emit AppAddedToLicense(app, licenseOwner);
    }

    /**
     * @notice Internal helper that unlinks an app from a license owner. Reverts if
     * `app` is not currently linked to `licenseOwner`. Emits AppRemovedFromLicense.
     */
    function _removeAppFromLicense(address app, address licenseOwner) private {
        require(app != address(0), InvalidZeroAddress());
        require(licenseOwner != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require($.appLicensors[app] == licenseOwner, AppNotLinkedToLicense(app, licenseOwner));
        delete $.appLicensors[app];
        emit AppRemovedFromLicense(app, licenseOwner);
    }
}
