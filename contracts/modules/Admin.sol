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
    ) external override onlyOwner {
        _validateLicenseParams(licenseOwner, expirationDate, monthlyQuota);
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require(!_licenseExists(licenseOwner), LicenseAlreadyExists(licenseOwner));
        // TODO: initialize `quotaLastResetMonth` with the current month once on-chain
        // date utilities (e.g. solady DateTimeLib) are wired into the contract.
        $.licenses[licenseOwner] = License({
            expirationDate: expirationDate,
            quotaLastResetMonth: 0,
            monthlyQuota: monthlyQuota,
            consumedQuota: 0
        });
        emit LicenseSet(licenseOwner, expirationDate, monthlyQuota);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function renewLicense(
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) external override onlyOwner {
        _validateLicenseParams(licenseOwner, expirationDate, monthlyQuota);
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        License memory currentLicense = $.licenses[licenseOwner];
        require(expirationDate > currentLicense.expirationDate, InvalidExpirationDate());
        if (!_licenseExists(licenseOwner)) {
            // No live entry: initialize all fields just like createLicense.
            // TODO: initialize `quotaLastResetMonth` once date utilities are wired in.
            $.licenses[licenseOwner] = License({
                expirationDate: expirationDate,
                quotaLastResetMonth: 0,
                monthlyQuota: monthlyQuota,
                consumedQuota: 0
            });
        } else {
            // Existing entry: only refresh expiration and monthly quota. consumedQuota and
            // quotaLastResetMonth carry over; the new monthlyQuota applies starting at next
            // month's lazy reset.
            $.licenses[licenseOwner] = License({
                expirationDate: expirationDate,
                quotaLastResetMonth: currentLicense.quotaLastResetMonth,
                monthlyQuota: monthlyQuota,
                consumedQuota: currentLicense.consumedQuota
            });
        }
        emit LicenseSet(licenseOwner, expirationDate, monthlyQuota);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function revokeLicense(address licenseOwner) external override onlyOwner {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require(_licenseExists(licenseOwner), LicenseNotFound(licenseOwner));
        delete $.licenses[licenseOwner];
        emit LicenseRevoked(licenseOwner);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function linkAppToLicense(address app, address licenseOwner) external override onlyOwner {
        _linkAppToLicense(app, licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function linkAppToLicense(address app) external override {
        _linkAppToLicense(app, msg.sender);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function unlinkAppFromLicense(address app, address licenseOwner) external override onlyOwner {
        _unlinkAppFromLicense(app, licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function unlinkAppFromLicense(address app) external override {
        // The link check inside _unlinkAppFromLicense (appLicensors[app] == msg.sender)
        // implicitly enforces that the caller owns the link being removed.
        _unlinkAppFromLicense(app, msg.sender);
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

    /// @inheritdoc INoxCompute
    function license(address licenseOwner) external view override returns (License memory) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.licenses[licenseOwner];
    }

    /// @inheritdoc INoxCompute
    function appLicense(
        address app
    ) external view override returns (address licenseOwner, License memory licenseEntry) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        licenseOwner = $.appLicensors[app];
        licenseEntry = $.licenses[licenseOwner];
    }

    /**
     * Authorizes contract upgrades only by the owner.
     */
    function _authorizeUpgrade(address /*newImplementation*/) internal override onlyOwner {}

    /**
     * @dev Validates the common license inputs: non-zero owner, future expiration date,
     * and non-zero monthly quota. Implemented as a private function (cheaper than a
     * modifier when reused across multiple call sites).
     */
    function _validateLicenseParams(
        address owner,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) private view {
        require(owner != address(0), InvalidZeroAddress());
        require(expirationDate > block.timestamp, InvalidExpirationDate());
        require(monthlyQuota != 0, InvalidMonthlyQuota());
    }

    /**
     * @dev Returns true if a license record exists for `licenseOwner` (expirationDate != 0).
     * When called after already reading the license slot (e.g. in renewLicense), the second
     * SLOAD hits a warm slot (100 gas); acceptable for an onlyOwner admin function.
     */
    function _licenseExists(address licenseOwner) private view returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.licenses[licenseOwner].expirationDate != 0;
    }

    /**
     * @dev Returns true if `licenseOwner` holds a non-expired license.
     * Covers both the not-found case (expirationDate == 0) and the expired case.
     */
    function _licenseActive(address licenseOwner) private view returns (bool) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return $.licenses[licenseOwner].expirationDate > block.timestamp;
    }

    /**
     * @notice Internal helper that links an app to a license owner. The owner must
     * hold an active license (non-expired).
     * Emits AppLinkedToLicense.
     */
    function _linkAppToLicense(address app, address licenseOwner) private {
        require(app != address(0), InvalidZeroAddress());
        require(licenseOwner != address(0), InvalidZeroAddress());
        require(_licenseActive(licenseOwner), LicenseNotActive(licenseOwner));
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.appLicensors[app] = licenseOwner;
        emit AppLinkedToLicense(app, licenseOwner);
    }

    /**
     * @notice Internal helper that unlinks an app from a license owner. Reverts if
     * `app` is not currently linked to `licenseOwner`. Emits AppUnlinkedFromLicense.
     */
    function _unlinkAppFromLicense(address app, address licenseOwner) private {
        require(app != address(0), InvalidZeroAddress());
        require(licenseOwner != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require($.appLicensors[app] == licenseOwner, AppNotLinkedToLicense(app, licenseOwner));
        delete $.appLicensors[app];
        emit AppUnlinkedFromLicense(app, licenseOwner);
    }
}
