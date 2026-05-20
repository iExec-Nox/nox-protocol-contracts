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
        uint32 firstExpiration = uint32(block.timestamp + 30 days);
        uint32 secondExpiration = uint32(block.timestamp + 60 days);

        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, firstExpiration, 1000);

        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(app, licenseOwner, secondExpiration, 2000);
        noxCompute.setLicense(app, licenseOwner, secondExpiration, 2000);
    }

    function test_RevertWhen_SetLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.setLicense(app, licenseOwner, uint32(block.timestamp + 30 days), 1000);
    }

    function test_RevertWhen_SetLicense_ZeroApp() public {
        vm.expectRevert(INoxCompute.InvalidAppAddress.selector);
        vm.prank(owner);
        noxCompute.setLicense(address(0), licenseOwner, uint32(block.timestamp + 30 days), 1000);
    }

    function test_RevertWhen_SetLicense_ZeroLicenseOwner() public {
        vm.expectRevert(INoxCompute.InvalidLicenseOwnerAddress.selector);
        vm.prank(owner);
        noxCompute.setLicense(app, address(0), uint32(block.timestamp + 30 days), 1000);
    }

    function test_RevertWhen_SetLicense_ZeroExpirationDate() public {
        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, 0, 1000);
    }

    function test_RevertWhen_SetLicense_ZeroMonthlyQuota() public {
        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, uint32(block.timestamp + 30 days), 0);
    }

    // ============ renewLicense ============

    function test_RenewLicense() public {
        // Provision a license first
        uint32 initialExpiration = uint32(block.timestamp + 30 days);
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, initialExpiration, 1000);

        // Renew it
        uint32 newExpiration = uint32(block.timestamp + 365 days);
        uint24 newQuota = 5000;
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseSet(app, licenseOwner, newExpiration, newQuota);
        noxCompute.renewLicense(app, newExpiration, newQuota);
    }

    function test_RevertWhen_RenewLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.renewLicense(app, uint32(block.timestamp + 30 days), 1000);
    }

    function test_RevertWhen_RenewLicense_NoExistingLicense() public {
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.LicenseNotFound.selector, app));
        vm.prank(owner);
        noxCompute.renewLicense(app, uint32(block.timestamp + 30 days), 1000);
    }

    function test_RevertWhen_RenewLicense_ZeroExpirationDate() public {
        // Provision a license first
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, uint32(block.timestamp + 30 days), 1000);

        vm.expectRevert(INoxCompute.InvalidExpirationDate.selector);
        vm.prank(owner);
        noxCompute.renewLicense(app, 0, 1000);
    }

    function test_RevertWhen_RenewLicense_ZeroMonthlyQuota() public {
        // Provision a license first
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, uint32(block.timestamp + 30 days), 1000);

        vm.expectRevert(INoxCompute.InvalidMonthlyQuota.selector);
        vm.prank(owner);
        noxCompute.renewLicense(app, uint32(block.timestamp + 60 days), 0);
    }

    // ============ revokeLicense ============

    function test_RevokeLicense() public {
        // Provision a license first
        vm.prank(owner);
        noxCompute.setLicense(app, licenseOwner, uint32(block.timestamp + 30 days), 1000);

        // Revoke it
        vm.prank(owner);
        vm.expectEmit();
        emit INoxCompute.LicenseRevoked(app, licenseOwner);
        noxCompute.revokeLicense(app);
    }

    function test_RevertWhen_RevokeLicense_UnauthorizedCaller() public {
        address unauthorizedCaller = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector,
                unauthorizedCaller,
                noxCompute
            )
        );
        vm.prank(unauthorizedCaller);
        noxCompute.revokeLicense(app);
    }

    function test_RevertWhen_RevokeLicense_NoExistingLicense() public {
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.LicenseNotFound.selector, app));
        vm.prank(owner);
        noxCompute.revokeLicense(app);
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
}
