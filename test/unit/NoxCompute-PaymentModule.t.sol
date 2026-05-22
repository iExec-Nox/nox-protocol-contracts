// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TEEType} from "../../contracts/utils/TypeUtils.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxCompute_PaymentTest is Test {
    address owner = makeAddr("owner");
    address gateway = vm.addr(123456789);
    NoxCompute noxCompute;

    address app = makeAddr("app");
    address sponsor = makeAddr("sponsor");
    address licenseOwner = makeAddr("licenseOwner");

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway, 1);
        vm.label(app, "app");
        vm.label(sponsor, "sponsor");
        vm.label(licenseOwner, "licenseOwner");
    }

    // ============ Kill switch ============

    function test_NoOp_WhenPaymentDisabled() public {}

    // ============ License path ============

    function test_LicensePath_OperationSucceeds() public {}

    function test_LicensePath_ConsumedQuotaIncrements() public {}

    function test_LicensePath_ConsumedQuotaIncrementsAfterNOperations() public {}

    function test_LicensePath_LicenseTakesPriorityOverSponsor() public {}

    function test_RevertWhen_LicensePath_QuotaExhausted_NoSponsor() public {}

    function test_RevertWhen_LicensePath_QuotaWouldOverflow_NoSponsor() public {}

    function test_RevertWhen_LicensePath_Expired_NoSponsor() public {}

    // ============ License fallback to sponsor ============

    function test_LicensePath_QuotaExhausted_FallsBackToApprovedSponsor() public {}

    function test_LicensePath_QuotaWouldOverflow_FallsBackToApprovedSponsor() public {}

    function test_LicensePath_Expired_FallsBackToApprovedSponsor() public {}

    // ============ Sponsor path ============

    function test_SponsorPath_NoOp_WhenPriceInUsdcIsZero() public {}

    function test_SponsorPath_ApprovedSponsor_OperationSucceeds() public {}

    function test_RevertWhen_SponsorPath_PendingSponsor() public {}

    function test_RevertWhen_NoApprovedSponsor() public {}

    // ============ Multi-app / shared license ============

    function test_MultipleApps_SameLicenseOwner_QuotaTrackedShared() public {}

    function test_RevertWhen_MultipleApps_SameLicenseOwner_SharedQuotaExhausted() public {}

    // ============ Multi-app / shared sponsor ============

    function test_MultipleApps_SameSponsor_EachChargedIndependently() public {}

    function test_RevertWhen_MultipleApps_SameSponsor_OneNotApproved() public {}
}
