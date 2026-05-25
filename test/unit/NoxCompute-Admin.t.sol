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
    uint32 DEFAULT_EXPIRATION_DATE;
    NoxCompute noxCompute;

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway);
        vm.label(app, "app");
        vm.label(licenseOwner, "licenseOwner");
        DEFAULT_EXPIRATION_DATE = uint32(block.timestamp + 30 days);
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
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
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
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
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
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.setProofExpirationDuration(2 hours);
    }

    // ============ createLicense ============

    function test_CreateLicense() public {
        vm.prank(owner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.LicenseSet(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
        noxCompute.createLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);

        // Storage assertion via the new getter.
        INoxCompute.License memory entry = noxCompute.license(licenseOwner);
        assertEq(entry.expirationDate, DEFAULT_EXPIRATION_DATE);
        assertEq(entry.monthlyQuota, DEFAULT_QUOTA);
        assertEq(entry.consumedQuota, 0);
        assertEq(entry.quotaLastResetMonth, 0);
    }

    function test_CreateLicense_TwoDifferentOwnersGetIndependentLicenses() public {
        address otherOwner = makeAddr("otherOwner");
        uint24 otherQuota = 2000;
        uint32 otherExpiration = uint32(block.timestamp + 60 days);

        vm.startPrank(owner);
        noxCompute.createLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
        noxCompute.createLicense(otherOwner, otherExpiration, otherQuota);
        vm.stopPrank();

        INoxCompute.License memory a = noxCompute.license(licenseOwner);
        INoxCompute.License memory b = noxCompute.license(otherOwner);
        assertEq(a.expirationDate, DEFAULT_EXPIRATION_DATE);
        assertEq(a.monthlyQuota, DEFAULT_QUOTA);
        assertEq(b.expirationDate, otherExpiration);
        assertEq(b.monthlyQuota, otherQuota);
    }

    function test_RevertWhen_CreateLicense_AlreadyExists() public {
        _provisionDefaultLicense();
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.LicenseAlreadyExists.selector, licenseOwner)
        );
        vm.prank(owner);
        noxCompute.createLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
    }

    function test_RevertWhen_CreateLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.createLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
    }

    function test_RevertWhen_CreateLicense_ZeroOwner() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.createLicense(address(0), DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
    }

    function test_RevertWhen_CreateLicense_PastExpirationDate() public {
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.createLicense(licenseOwner, uint32(block.timestamp), DEFAULT_QUOTA);
    }

    function test_RevertWhen_CreateLicense_ZeroMonthlyQuota() public {
        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.createLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, 0);
    }

    // ============ renewLicense ============

    function test_RenewLicense_OnActiveLicense() public {
        _provisionDefaultLicense();

        uint32 newExpiration = uint32(block.timestamp + 365 days);
        uint24 newQuota = 5000;
        vm.prank(owner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.LicenseSet(licenseOwner, newExpiration, newQuota);
        noxCompute.renewLicense(licenseOwner, newExpiration, newQuota);

        INoxCompute.License memory entry = noxCompute.license(licenseOwner);
        assertEq(entry.expirationDate, newExpiration);
        assertEq(entry.monthlyQuota, newQuota);
    }

    function test_RenewLicense_OnRevokedLicense() public {
        // First provision then revoke.
        _provisionDefaultLicense();
        vm.prank(owner);
        noxCompute.revokeLicense(licenseOwner);

        // Renewing a revoked license behaves like createLicense: initializes all fields.
        uint32 newExpiration = uint32(block.timestamp + 365 days);
        vm.prank(owner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.LicenseSet(licenseOwner, newExpiration, DEFAULT_QUOTA);
        noxCompute.renewLicense(licenseOwner, newExpiration, DEFAULT_QUOTA);

        INoxCompute.License memory entry = noxCompute.license(licenseOwner);
        assertEq(entry.expirationDate, newExpiration);
        assertEq(entry.monthlyQuota, DEFAULT_QUOTA);
        assertEq(entry.consumedQuota, 0);
    }

    function test_RevertWhen_RenewLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.renewLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
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
        _provisionDefaultLicense();
        // Trying to renew with the same expiration must revert (not strictly greater).
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.renewLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
    }

    // ============ revokeLicense ============

    function test_RevokeLicense() public {
        _provisionDefaultLicense();

        vm.prank(owner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.LicenseRevoked(licenseOwner);
        noxCompute.revokeLicense(licenseOwner);

        // Storage check: entry is fully cleared.
        INoxCompute.License memory entry = noxCompute.license(licenseOwner);
        assertEq(entry.expirationDate, 0);
        assertEq(entry.monthlyQuota, 0);
        assertEq(entry.consumedQuota, 0);
        assertEq(entry.quotaLastResetMonth, 0);
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

    // ============ linkAppToLicense (admin) ============

    function test_LinkAppToLicense_AsAdmin() public {
        _provisionDefaultLicense();

        vm.prank(owner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.AppLinkedToLicense(app, licenseOwner);
        noxCompute.linkAppToLicense(app, licenseOwner);

        // Storage check via appLicense getter.
        (address linkedOwner, INoxCompute.License memory entry) = noxCompute.appLicense(app);
        assertEq(linkedOwner, licenseOwner);
        assertEq(entry.expirationDate, DEFAULT_EXPIRATION_DATE);
        assertEq(entry.monthlyQuota, DEFAULT_QUOTA);
    }

    function test_RevertWhen_LinkAppToLicense_AsAdmin_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.linkAppToLicense(app, licenseOwner);
    }

    function test_RevertWhen_LinkAppToLicense_AsAdmin_ZeroApp() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.linkAppToLicense(address(0), licenseOwner);
    }

    function test_RevertWhen_LinkAppToLicense_AsAdmin_ZeroLicenseOwner() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(owner);
        noxCompute.linkAppToLicense(app, address(0));
    }

    function test_RevertWhen_LinkAppToLicense_AsAdmin_LicenseNotActive() public {
        address unknownOwner = makeAddr("unknownOwner");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.LicenseNotActive.selector, unknownOwner)
        );
        vm.prank(owner);
        noxCompute.linkAppToLicense(app, unknownOwner);
    }

    // ============ linkAppToLicense (license owner) ============

    function test_LinkAppToLicense_LicenseOwner() public {
        _provisionDefaultLicense();

        vm.prank(licenseOwner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.AppLinkedToLicense(app, licenseOwner);
        noxCompute.linkAppToLicense(app);

        (address linkedOwner, ) = noxCompute.appLicense(app);
        assertEq(linkedOwner, licenseOwner);
    }

    function test_RevertWhen_LinkAppToLicense_LicenseOwner_ZeroApp() public {
        _provisionDefaultLicense();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(licenseOwner);
        noxCompute.linkAppToLicense(address(0));
    }

    function test_RevertWhen_LinkAppToLicense_LicenseOwner_CallerHasNoLicense() public {
        address callerWithoutLicense = makeAddr("noLicense");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.LicenseNotActive.selector, callerWithoutLicense)
        );
        vm.prank(callerWithoutLicense);
        noxCompute.linkAppToLicense(app);
    }

    // ============ unlinkAppFromLicense (admin) ============

    function test_UnlinkAppFromLicense_AsAdmin() public {
        _provisionDefaultLicense();
        vm.prank(owner);
        noxCompute.linkAppToLicense(app, licenseOwner);

        vm.prank(owner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.AppUnlinkedFromLicense(app, licenseOwner);
        noxCompute.unlinkAppFromLicense(app, licenseOwner);

        (address linkedOwner, ) = noxCompute.appLicense(app);
        assertEq(linkedOwner, address(0));
    }

    function test_RevertWhen_UnlinkAppFromLicense_AsAdmin_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedCaller);
        vm.prank(unauthorizedCaller);
        noxCompute.unlinkAppFromLicense(app, licenseOwner);
    }

    function test_RevertWhen_UnlinkAppFromLicense_AsAdmin_NotLinked() public {
        _provisionDefaultLicense();
        // app was never linked to licenseOwner.
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.AppNotLinkedToLicense.selector, app, licenseOwner)
        );
        vm.prank(owner);
        noxCompute.unlinkAppFromLicense(app, licenseOwner);
    }

    function test_RevertWhen_UnlinkAppFromLicense_AsAdmin_WrongOwner() public {
        _provisionDefaultLicense();
        vm.prank(owner);
        noxCompute.linkAppToLicense(app, licenseOwner);

        address otherOwner = makeAddr("otherOwner");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.AppNotLinkedToLicense.selector, app, otherOwner)
        );
        vm.prank(owner);
        noxCompute.unlinkAppFromLicense(app, otherOwner);
    }

    // ============ unlinkAppFromLicense (license owner) ============

    function test_UnlinkAppFromLicense_LicenseOwner() public {
        _provisionDefaultLicense();
        // licenseOwner links the app to their own license.
        vm.prank(licenseOwner);
        noxCompute.linkAppToLicense(app);

        vm.prank(licenseOwner);
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.AppUnlinkedFromLicense(app, licenseOwner);
        noxCompute.unlinkAppFromLicense(app);
    }

    function test_RevertWhen_UnlinkAppFromLicense_LicenseOwner_ZeroApp() public {
        _provisionDefaultLicense();
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(licenseOwner);
        noxCompute.unlinkAppFromLicense(address(0));
    }

    function test_RevertWhen_UnlinkAppFromLicense_LicenseOwner_NotCallersApp() public {
        _provisionDefaultLicense();
        // app linked to licenseOwner (not the random caller below).
        vm.prank(owner);
        noxCompute.linkAppToLicense(app, licenseOwner);

        address otherCaller = makeAddr("otherCaller");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.AppNotLinkedToLicense.selector, app, otherCaller)
        );
        vm.prank(otherCaller);
        noxCompute.unlinkAppFromLicense(app);
    }

    // ============ _authorizeUpgrade ============

    function test_AuthorizeUpgrade() public {
        address newImplementation = address(TestHelper.newImplementationInstance());
        vm.prank(owner);
        vm.expectEmit();
        emit IERC1967.Upgraded(newImplementation);
        noxCompute.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradeToAndCall_UnauthorizedCaller() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        _expectOwnableUnauthorizedRevert(unauthorizedUpgrader);
        vm.prank(unauthorizedUpgrader);
        noxCompute.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Helpers ============

    function _provisionDefaultLicense() internal {
        vm.prank(owner);
        noxCompute.createLicense(licenseOwner, DEFAULT_EXPIRATION_DATE, DEFAULT_QUOTA);
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
