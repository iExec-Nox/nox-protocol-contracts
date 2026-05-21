// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Common} from "./Common.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Admin
 * @notice Role-based admin layer for NoxCompute.
 * @dev Four roles drive privileged actions:
 *      - DEFAULT_ADMIN_ROLE: grants/revokes other roles (multisig).
 *      - UPGRADER_ROLE: authorizes UUPS upgrades (`upgradeToAndCall`).
 *      - INFRA_ROLE: updates infrastructure config (KMS public key, gateway address,
 *        proof expiration duration).
 *      - PAYMENT_MANAGER_ROLE: provisions, renews, revokes, and links licenses.
 */
abstract contract Admin is Common, AccessControlUpgradeable, UUPSUpgradeable {
    /// @notice Role allowed to upgrade the proxy implementation.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// @notice Role allowed to update infrastructure config (KMS key, gateway, proof expiration).
    bytes32 public constant INFRA_ROLE = keccak256("INFRA_ROLE");
    /// @notice Role allowed to manage licenses (provision, renew, revoke, link apps).
    bytes32 public constant PAYMENT_MANAGER_ROLE = keccak256("PAYMENT_MANAGER_ROLE");

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
     * Only callable by an INFRA_ROLE holder.
     * @param newKmsPublicKey Compressed SEC1 secp256k1 public key (33 bytes)
     */
    function setKmsPublicKey(
        bytes calldata newKmsPublicKey
    ) external override onlyRole(INFRA_ROLE) {
        require(newKmsPublicKey.length != 0, InvalidEmptyBytes());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.kmsPublicKey = newKmsPublicKey;
        emit KmsPublicKeyUpdated(newKmsPublicKey);
    }

    /**
     * Sets Gateway wallet address.
     * Only callable by an INFRA_ROLE holder.
     * @param gatewayAddress New Gateway wallet address
     */
    function setGateway(address gatewayAddress) external override onlyRole(INFRA_ROLE) {
        require(gatewayAddress != address(0), InvalidZeroAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.gateway = gatewayAddress;
        emit GatewayUpdated(gatewayAddress);
    }

    /**
     * Sets the proof expiration duration.
     * Only callable by an INFRA_ROLE holder.
     * @param newDuration New expiration duration in seconds
     */
    function setProofExpirationDuration(
        uint256 newDuration
    ) external override onlyRole(INFRA_ROLE) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.proofExpirationDuration = newDuration;
        emit ProofExpirationDurationUpdated(newDuration);
    }

    /// @inheritdoc INoxCompute
    function setLicense(
        address app,
        address licenseOwner,
        uint32 expirationDate,
        uint24 monthlyQuota
    )
        external
        override
        onlyRole(PAYMENT_MANAGER_ROLE)
        validLicenseParams(app, expirationDate, monthlyQuota)
    {
        require(licenseOwner != address(0), InvalidLicenseOwnerAddress());
        _setLicense(app, licenseOwner, expirationDate, monthlyQuota);
    }

    /// @inheritdoc INoxCompute
    function renewLicense(
        address app,
        uint32 expirationDate,
        uint24 monthlyQuota
    )
        external
        override
        onlyRole(PAYMENT_MANAGER_ROLE)
        validLicenseParams(app, expirationDate, monthlyQuota)
    {
        address licenseOwner = _getNoxComputeStorage().appLicensors[app];
        require(licenseOwner != address(0), LicenseNotFound(app));
        _setLicense(app, licenseOwner, expirationDate, monthlyQuota);
    }

    /// @inheritdoc INoxCompute
    function revokeLicense(address app) external override onlyRole(PAYMENT_MANAGER_ROLE) {
        require(_getNoxComputeStorage().appLicensors[app] != address(0), LicenseNotFound(app));
        _setLicense(app, address(0), 0, 0);
    }

    /// @inheritdoc INoxCompute
    function setAppLicense(
        address app,
        address licenseOwner
    ) external override onlyRole(PAYMENT_MANAGER_ROLE) {
        _setAppLicense(app, licenseOwner);
    }

    /// @inheritdoc INoxCompute
    function setAppLicense(address app) external override {
        _setAppLicense(app, msg.sender);
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

    /**
     * @notice Internal helper that links/unlinks an app to a license owner.
     * If licenseOwner == address(0), the app is unlinked and AppLicenseUnset is emitted.
     * Otherwise, the licenseOwner must hold an active license, the link is recorded and
     * AppLicenseSet is emitted.
     */
    function _setAppLicense(address app, address licenseOwner) private {
        require(app != address(0), InvalidAppAddress());
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        if (licenseOwner == address(0)) {
            address previousOwner = $.appLicensors[app];
            delete $.appLicensors[app];
            emit AppLicenseUnset(app, previousOwner);
        } else {
            require(
                $.licenses[licenseOwner].expirationDate != 0,
                LicenseOwnerHasNoLicense(licenseOwner)
            );
            $.appLicensors[app] = licenseOwner;
            emit AppLicenseSet(app, licenseOwner);
        }
    }
}
