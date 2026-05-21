// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxCompute_AdminTest is Test {
    address owner = makeAddr("owner");
    uint256 gatewayPrivateKey = 123456789;
    address gateway = vm.addr(gatewayPrivateKey);
    address app = makeAddr("app");
    address licenseOwner = makeAddr("licenseOwner");
    uint24 constant DEFAULT_QUOTA = 1000;
    uint32 constant DEFAULT_EXPIRATION_OFFSET = 30 days;
    NoxCompute noxCompute;

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway);
        vm.label(app, "app");
        vm.label(licenseOwner, "licenseOwner");
    }

    // ============ setKmsPublicKey ============

    function test_SetKmsPublicKey() public {
        // 33-byte compressed SEC1 secp256k1 public key
        bytes memory newKey = abi.encodePacked(bytes1(0x02), keccak256("new-kms-key"));
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.KmsPublicKeyUpdated(newKey);
        noxCompute.setKmsPublicKey(newKey);
        assertEq(noxCompute.kmsPublicKey(), newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        bytes memory newKey = abi.encodePacked(bytes1(0x02), keccak256("unauthorized-kms-key"));
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setKmsPublicKey(newKey);
    }

    function test_RevertWhen_SetKmsPublicKey_EmptyKey() public {
        vm.expectRevert(INoxCompute.InvalidEmptyBytes.selector);
        vm.prank(owner);
        noxCompute.setKmsPublicKey("");
    }

    // ============ setGateway ============

    function test_SetGateway() public {
        assertTrue(noxCompute.gateway() == gateway);
        address newGateway = makeAddr("newGateway");
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.GatewayUpdated(newGateway);
        noxCompute.setGateway(newGateway);
        assertTrue(noxCompute.gateway() == newGateway);
    }

    function test_RevertWhen_SetGateway_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        address newGateway = makeAddr("newGateway");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setGateway(newGateway);
    }

    function test_RevertWhen_SetGateway_ZeroAddress() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.setGateway(address(0));
    }

    // ============ setProofExpirationDuration ============

    function test_SetProofExpirationDuration() public {
        // Default is set during initialization
        assertEq(noxCompute.proofExpirationDuration(), 1 hours);

        uint256 newDuration = 2 hours;
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.ProofExpirationDurationUpdated(newDuration);
        noxCompute.setProofExpirationDuration(newDuration);
        assertEq(noxCompute.proofExpirationDuration(), newDuration);
    }

    function test_RevertWhen_SetProofExpirationDuration_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setProofExpirationDuration(2 hours);
    }

    // ============ createLicense ============

    function test_CreateLicense() public {
        uint32 expirationDate = uint32(block.timestamp + 365 days);
        uint24 monthlyQuota = 1_000_000;

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(licenseOwner, expirationDate, monthlyQuota);
        noxCompute.createLicense(licenseOwner, expirationDate, monthlyQuota);
    }

    function test_RevertWhen_CreateLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.createLicense(
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_CreateLicense_ZeroOwner() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.createLicense(
            address(0),
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_CreateLicense_PastExpirationDate() public {
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.createLicense(licenseOwner, uint32(block.timestamp), DEFAULT_QUOTA);
    }

    function test_RevertWhen_CreateLicense_ZeroMonthlyQuota() public {
        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.createLicense(
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            0
        );
    }

    // ============ renewLicense ============

    function test_RenewLicense_OnActiveLicense() public {
        _provisionDefaultLicense();

        uint32 newExpiration = uint32(block.timestamp + 365 days);
        uint24 newQuota = 5000;
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(licenseOwner, newExpiration, newQuota);
        noxCompute.renewLicense(licenseOwner, newExpiration, newQuota);
    }

    function test_RenewLicense_OnRevokedLicense() public {
        // First provision then revoke.
        _provisionDefaultLicense();
        vm.prank(owner);
        noxCompute.revokeLicense(licenseOwner);

        // Renewing a revoked license should work without any existence check.
        uint32 newExpiration = uint32(block.timestamp + 365 days);
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(licenseOwner, newExpiration, DEFAULT_QUOTA);
        noxCompute.renewLicense(licenseOwner, newExpiration, DEFAULT_QUOTA);
    }

    function test_RevertWhen_RenewLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.renewLicense(
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_RenewLicense_PastExpirationDate() public {
        _provisionDefaultLicense();
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.renewLicense(licenseOwner, uint32(block.timestamp), DEFAULT_QUOTA);
    }

    function test_RevertWhen_RenewLicense_ZeroMonthlyQuota() public {
        _provisionDefaultLicense();
        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.renewLicense(licenseOwner, uint32(block.timestamp + 60 days), 0);
    }

    function test_RevertWhen_RenewLicense_ExpirationNotAfterOld() public {
        // Default license expires at block.timestamp + DEFAULT_EXPIRATION_OFFSET (30 days).
        _provisionDefaultLicense();
        // Trying to renew with the same expiration must revert (not strictly greater).
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.renewLicense(
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    // ============ revokeLicense ============

    function test_RevokeLicense() public {
        _provisionDefaultLicense();

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseRevoked(licenseOwner);
        noxCompute.revokeLicense(licenseOwner);
    }

    function test_RevertWhen_RevokeLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.revokeLicense(licenseOwner);
    }

    function test_RevertWhen_RevokeLicense_NoExistingLicense() public {
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.LicenseNotFound.selector, licenseOwner));
        vm.prank(owner);
        noxCompute.revokeLicense(licenseOwner);
    }

    // ============ addAppToLicense (admin) ============

    function test_AddAppToLicense_AsAdmin() public {
        _provisionDefaultLicense();
        address newApp = makeAddr("newApp");

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.AppAddedToLicense(newApp, licenseOwner);
        noxCompute.addAppToLicense(newApp, licenseOwner);
    }

    function test_RevertWhen_AddAppToLicense_AsAdmin_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.addAppToLicense(app, licenseOwner);
    }

    function test_RevertWhen_AddAppToLicense_AsAdmin_ZeroApp() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.addAppToLicense(address(0), licenseOwner);
    }

    function test_RevertWhen_AddAppToLicense_AsAdmin_ZeroLicenseOwner() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.addAppToLicense(app, address(0));
    }

    function test_RevertWhen_AddAppToLicense_AsAdmin_LicenseOwnerHasNoLicense() public {
        address unknownOwner = makeAddr("unknownOwner");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.LicenseOwnerHasNoLicense.selector, unknownOwner)
        );
        vm.prank(owner);
        noxCompute.addAppToLicense(app, unknownOwner);
    }

    // ============ addAppToLicense (self-service) ============

    function test_AddAppToLicense_SelfService() public {
        _provisionDefaultLicense();
        address newApp = makeAddr("newApp");

        vm.prank(licenseOwner);
        vm.expectEmit();
        emit INoxCompute.AppAddedToLicense(newApp, licenseOwner);
        noxCompute.addAppToLicense(newApp);
    }

    function test_RevertWhen_AddAppToLicense_SelfService_ZeroApp() public {
        _provisionDefaultLicense();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(licenseOwner);
        noxCompute.addAppToLicense(address(0));
    }

    function test_RevertWhen_AddAppToLicense_SelfService_CallerHasNoLicense() public {
        address callerWithoutLicense = makeAddr("noLicense");
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.LicenseOwnerHasNoLicense.selector,
                callerWithoutLicense
            )
        );
        vm.prank(callerWithoutLicense);
        noxCompute.addAppToLicense(app);
    }

    // ============ removeAppFromLicense ============

    function test_RemoveAppFromLicense() public {
        _provisionDefaultLicense();
        vm.prank(owner);
        noxCompute.addAppToLicense(app, licenseOwner);

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.AppRemovedFromLicense(app, licenseOwner);
        noxCompute.removeAppFromLicense(app, licenseOwner);
    }

    function test_RevertWhen_RemoveAppFromLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.removeAppFromLicense(app, licenseOwner);
    }

    function test_RevertWhen_RemoveAppFromLicense_NotLinked() public {
        _provisionDefaultLicense();
        // app was never linked to licenseOwner.
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.AppNotLinkedToLicense.selector, app, licenseOwner)
        );
        vm.prank(owner);
        noxCompute.removeAppFromLicense(app, licenseOwner);
    }

    function test_RevertWhen_RemoveAppFromLicense_WrongOwner() public {
        _provisionDefaultLicense();
        vm.prank(owner);
        noxCompute.addAppToLicense(app, licenseOwner);

        address otherOwner = makeAddr("otherOwner");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.AppNotLinkedToLicense.selector, app, otherOwner)
        );
        vm.prank(owner);
        noxCompute.removeAppFromLicense(app, otherOwner);
    }

    // ============ _authorizeUpgrade ============

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(new NoxCompute());
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        noxCompute.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradeToAndCall_UnauthorizedCaller() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                noxCompute
            )
        );
        vm.prank(unauthorizedUpgrader);
        noxCompute.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Helpers ============

    function _provisionDefaultLicense() internal {
        vm.prank(owner);
        noxCompute.createLicense(
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function _expectOwnableUnauthorizedRevert(address caller) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                caller,
                noxCompute
            )
        );
    }
}
