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
     * @dev Validates the common license inputs: non-zero app, expiration date, and monthly quota.
     */
    modifier validLicenseParams(address app, uint32 expirationDate, uint24 monthlyQuota) {
        require(app != address(0), InvalidAppAddress());
        require(expirationDate != 0, InvalidExpirationDate());
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
    function setLicense(
        address app,
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) external virtual override onlyOwner validLicenseParams(app, expirationDate, monthlyQuota) {
        require(licenseOwner != address(0), InvalidLicenseOwnerAddress());
        _setLicense(app, licenseOwner, expirationDate, monthlyQuota);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function renewLicense(
        address app,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) external virtual override onlyOwner validLicenseParams(app, expirationDate, monthlyQuota) {
        address licenseOwner = _getNoxComputeStorage().appLicensors[app];
        require(licenseOwner != address(0), LicenseNotFound(app));
        _setLicense(app, licenseOwner, expirationDate, monthlyQuota);
    }

    // TODO: restrict to PAYMENT_MANAGER_ROLE once AccessControl replaces OwnableUpgradeable.
    /// @inheritdoc INoxCompute
    function revokeLicense(address app) external virtual override onlyOwner {
        require(_getNoxComputeStorage().appLicensors[app] != address(0), LicenseNotFound(app));
        _setLicense(app, address(0), 0, 0);
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
     * @notice Internal helper that applies the license mutation.
     * When expirationDate == 0, the app's licensor mapping is cleared and a LicenseRevoked
     * event is emitted. Otherwise, the licensor is updated, the owner's License struct is
     * refreshed (consumedQuota is reset to 0), and a LicenseSet event is emitted.
     */
    function _setLicense(
        address app,
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    ) private {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        if (expirationDate == 0) {
            address previousOwner = $.appLicensors[app];
            delete $.appLicensors[app];
            emit LicenseRevoked(app, previousOwner);
        } else {
            $.appLicensors[app] = licenseOwner;
            License storage license = $.licenses[licenseOwner];
            license.expirationDate = expirationDate;
            license.monthlyQuota = monthlyQuota;
            license.consumedQuota = 0;
            emit LicenseSet(app, licenseOwner, expirationDate, monthlyQuota);
        }
    }
}
