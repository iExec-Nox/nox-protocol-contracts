// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Common} from "./Common.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Admin
 * @notice Configuration of KMS public key, gateway address, and proof expiration.
 * @notice Owner-only functions to set configuration and manage upgrades.
 */
abstract contract Admin is Common, OwnableUpgradeable, UUPSUpgradeable {
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
     * Only callable by the owner.
     * @param newKmsPublicKey Compressed SEC1 secp256k1 public key (33 bytes)
     */
    function setKmsPublicKey(bytes calldata newKmsPublicKey) external override onlyOwner {
        require(newKmsPublicKey.length != 0, InvalidEmptyBytes());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.kmsPublicKey = newKmsPublicKey;
        emit KmsPublicKeyUpdated(newKmsPublicKey);
    }

    /**
     * Sets Gateway wallet address.
     * Only callable by the owner.
     * @param gatewayAddress New Gateway wallet address
     */
    function setGateway(address gatewayAddress) external override onlyOwner {
        require(gatewayAddress != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.gateway = gatewayAddress;
        emit GatewayUpdated(gatewayAddress);
    }

    /**
     * Sets the proof expiration duration.
     * Only callable by the owner.
     * @param newDuration New expiration duration in seconds
     */
    function setProofExpirationDuration(uint256 newDuration) external override onlyOwner {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = newDuration;
        emit ProofExpirationDurationUpdated(newDuration);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function createLicense(
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) external override onlyOwner validLicenseParams(licenseOwner, expirationDate, monthlyQuota) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        license.expirationDate = expirationDate;
        license.monthlyQuota = monthlyQuota;
        emit LicenseSet(licenseOwner, expirationDate, monthlyQuota);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function renewLicense(
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) external override onlyOwner validLicenseParams(licenseOwner, expirationDate, monthlyQuota) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        require(expirationDate > license.expirationDate, InvalidExpirationDate());
        license.expirationDate = expirationDate;
        license.monthlyQuota = monthlyQuota;
        // consumedQuota is intentionally NOT reset: the new monthlyQuota only applies starting
        // at next month's lazy reset, the current-month usage carries over.
        emit LicenseSet(licenseOwner, expirationDate, monthlyQuota);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function revokeLicense(address licenseOwner) external override onlyOwner {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License storage license = $.licenses[licenseOwner];
        require(license.expirationDate != 0, LicenseNotFound(licenseOwner));
        delete $.licenses[licenseOwner];
        emit LicenseRevoked(licenseOwner);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function addAppToLicense(address app, address licenseOwner) external override onlyOwner {
        _addAppToLicense(app, licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function addAppToLicense(address app) external override {
        _addAppToLicense(app, msg.sender);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function removeAppFromLicense(address app, address licenseOwner) external override onlyOwner {
        require(app != address(0), InvalidZeroAddress());
        require(licenseOwner != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require($.appLicensors[app] == licenseOwner, AppNotLinkedToLicense(app, licenseOwner));
        delete $.appLicensors[app];
        emit AppRemovedFromLicense(app, licenseOwner);
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
     * Authorizes contract upgrades only by the owner.
     */
    function _authorizeUpgrade(address /*newImplementation*/) internal override onlyOwner {}

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
}
