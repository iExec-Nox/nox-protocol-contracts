// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {IERC1967} from "@openzeppelin/contracts/interfaces/IERC1967.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
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
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.INFRA_ROLE());
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
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.INFRA_ROLE());
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
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.INFRA_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.setProofExpirationDuration(2 hours);
    }

    // ============ setLicense ============

    function test_SetLicense() public {
        uint32 expirationDate = uint32(block.timestamp + 365 days);
        uint24 monthlyQuota = 1_000_000;

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(app, licenseOwner, expirationDate, monthlyQuota);
        noxCompute.setLicense(app, licenseOwner, expirationDate, monthlyQuota);
    }

    function test_SetLicense_OverwritesExistingLicense() public {
        _provisionDefaultLicense();

        uint32 newExpiration = uint32(block.timestamp + 60 days);
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(app, licenseOwner, newExpiration, 2000);
        noxCompute.setLicense(app, licenseOwner, newExpiration, 2000);
    }

    function test_RevertWhen_SetLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.PAYMENT_MANAGER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.setLicense(
            app,
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_SetLicense_ZeroApp() public {
        vm.expectRevert(INoxCompute.InvalidAppAddress.selector);
        vm.prank(owner);
        noxCompute.setLicense(
            address(0),
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_SetLicense_ZeroLicenseOwner() public {
        vm.expectRevert(INoxCompute.InvalidLicenseOwnerAddress.selector);
        vm.prank(owner);
        noxCompute.setLicense(
            app,
            address(0),
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_SetLicense_ZeroExpirationDate() public {
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, 0, DEFAULT_QUOTA);
    }

    function test_RevertWhen_SetLicense_ZeroMonthlyQuota() public {
        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.setLicense(
            app,
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            0
        );
    }

    // ============ renewLicense ============

    function test_RenewLicense() public {
        _provisionDefaultLicense();

        uint32 newExpiration = uint32(block.timestamp + 365 days);
        uint24 newQuota = 5000;
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(app, licenseOwner, newExpiration, newQuota);
        noxCompute.renewLicense(app, newExpiration, newQuota);
    }

    function test_RevertWhen_RenewLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.PAYMENT_MANAGER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.renewLicense(
            app,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_RenewLicense_NoExistingLicense() public {
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.LicenseNotFound.selector, app));
        vm.prank(owner);
        noxCompute.renewLicense(
            app,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_RevertWhen_RenewLicense_ZeroExpirationDate() public {
        _provisionDefaultLicense();

        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.renewLicense(app, 0, DEFAULT_QUOTA);
    }

    function test_RevertWhen_RenewLicense_ZeroMonthlyQuota() public {
        _provisionDefaultLicense();

        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.renewLicense(app, uint32(block.timestamp + 60 days), 0);
    }

    // ============ revokeLicense ============

    function test_RevokeLicense() public {
        _provisionDefaultLicense();

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseRevoked(app, licenseOwner);
        noxCompute.revokeLicense(app);
    }

    function test_RevertWhen_RevokeLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.PAYMENT_MANAGER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.revokeLicense(app);
    }

    function test_RevertWhen_RevokeLicense_NoExistingLicense() public {
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.LicenseNotFound.selector, app));
        vm.prank(owner);
        noxCompute.revokeLicense(app);
    }

    // ============ setAppLicense (admin) ============

    function test_SetAppLicense_AsOwner() public {
        _provisionDefaultLicense();
        address newApp = makeAddr("newApp");

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.AppLicenseSet(newApp, licenseOwner);
        noxCompute.setAppLicense(newApp, licenseOwner);
    }

    function test_SetAppLicense_AsOwner_Unlink() public {
        _provisionDefaultLicense();

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.AppLicenseUnset(app, licenseOwner);
        noxCompute.setAppLicense(app, address(0));
    }

    function test_RevertWhen_SetAppLicense_AsOwner_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        _expectMissingRoleRevert(unauthorizedCaller, noxCompute.PAYMENT_MANAGER_ROLE());
        vm.prank(unauthorizedCaller);
        noxCompute.setAppLicense(app, licenseOwner);
    }

    function test_RevertWhen_SetAppLicense_AsOwner_ZeroApp() public {
        vm.expectRevert(INoxCompute.InvalidAppAddress.selector);
        vm.prank(owner);
        noxCompute.setAppLicense(address(0), licenseOwner);
    }

    function test_RevertWhen_SetAppLicense_AsOwner_LicenseOwnerHasNoLicense() public {
        address unknownOwner = makeAddr("unknownOwner");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.LicenseOwnerHasNoLicense.selector, unknownOwner)
        );
        vm.prank(owner);
        noxCompute.setAppLicense(app, unknownOwner);
    }

    // ============ setAppLicense (self-service) ============

    function test_SetAppLicense_SelfService() public {
        _provisionDefaultLicense();
        address newApp = makeAddr("newApp");

        vm.prank(licenseOwner);
        vm.expectEmit();
        emit INoxCompute.AppLicenseSet(newApp, licenseOwner);
        noxCompute.setAppLicense(newApp);
    }

    function test_RevertWhen_SetAppLicense_SelfService_ZeroApp() public {
        _provisionDefaultLicense();
        vm.expectRevert(INoxCompute.InvalidAppAddress.selector);
        vm.prank(licenseOwner);
        noxCompute.setAppLicense(address(0));
    }

    function test_RevertWhen_SetAppLicense_SelfService_CallerHasNoLicense() public {
        address callerWithoutLicense = makeAddr("noLicense");
        vm.expectRevert(
            abi.encodeWithSelector(
                INoxCompute.LicenseOwnerHasNoLicense.selector,
                callerWithoutLicense
            )
        );
        vm.prank(callerWithoutLicense);
        noxCompute.setAppLicense(app);
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
        _expectMissingRoleRevert(unauthorizedUpgrader, noxCompute.UPGRADER_ROLE());
        vm.prank(unauthorizedUpgrader);
        noxCompute.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ Role separation ============

    function test_Roles_PaymentManagerCannotCallInfra() public {
        address paymentManager = makeAddr("paymentManager");
        bytes32 pmRole = noxCompute.PAYMENT_MANAGER_ROLE();
        bytes32 infraRole = noxCompute.INFRA_ROLE();
        vm.prank(owner);
        noxCompute.grantRole(pmRole, paymentManager);

        _expectMissingRoleRevert(paymentManager, infraRole);
        vm.prank(paymentManager);
        noxCompute.setGateway(makeAddr("anyGateway"));
    }

    function test_Roles_UpgraderCannotCallInfra() public {
        address upgrader = makeAddr("upgrader");
        bytes32 upgraderRole = noxCompute.UPGRADER_ROLE();
        bytes32 infraRole = noxCompute.INFRA_ROLE();
        vm.prank(owner);
        noxCompute.grantRole(upgraderRole, upgrader);

        _expectMissingRoleRevert(upgrader, infraRole);
        vm.prank(upgrader);
        noxCompute.setGateway(makeAddr("anyGateway"));
    }

    function test_Roles_InfraCannotCallPaymentManager() public {
        address infra = makeAddr("infra");
        bytes32 pmRole = noxCompute.PAYMENT_MANAGER_ROLE();
        bytes32 infraRole = noxCompute.INFRA_ROLE();
        vm.prank(owner);
        noxCompute.grantRole(infraRole, infra);

        _expectMissingRoleRevert(infra, pmRole);
        vm.prank(infra);
        noxCompute.setLicense(
            app,
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function test_Roles_DedicatedHoldersCanCallTheirFunctions() public {
        address upgrader = makeAddr("upgrader");
        address infra = makeAddr("infra");
        address paymentManager = makeAddr("paymentManager");
        bytes32 upgraderRole = noxCompute.UPGRADER_ROLE();
        bytes32 infraRole = noxCompute.INFRA_ROLE();
        bytes32 pmRole = noxCompute.PAYMENT_MANAGER_ROLE();
        vm.startPrank(owner);
        noxCompute.grantRole(upgraderRole, upgrader);
        noxCompute.grantRole(infraRole, infra);
        noxCompute.grantRole(pmRole, paymentManager);
        vm.stopPrank();

        // INFRA can set gateway.
        address newGateway = makeAddr("freshGateway");
        vm.prank(infra);
        noxCompute.setGateway(newGateway);
        assertEq(noxCompute.gateway(), newGateway);

        // PAYMENT_MANAGER can set licenses.
        vm.prank(paymentManager);
        noxCompute.setLicense(
            app,
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );

        // UPGRADER can authorize an upgrade.
        address newImpl = address(new NoxCompute());
        vm.prank(upgrader);
        noxCompute.upgradeToAndCall(newImpl, "");
    }

    // ============ Helpers ============

    function _provisionDefaultLicense() internal {
        vm.prank(owner);
        noxCompute.setLicense(
            app,
            licenseOwner,
            uint32(block.timestamp + DEFAULT_EXPIRATION_OFFSET),
            DEFAULT_QUOTA
        );
    }

    function _expectMissingRoleRevert(address caller, bytes32 role) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                caller,
                role
            )
        );
    }
}
