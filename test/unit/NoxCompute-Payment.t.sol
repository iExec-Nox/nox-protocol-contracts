// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Test} from "forge-std/Test.sol";
import {NoxCompute} from "../../contracts/NoxCompute.sol";
import {INoxCompute} from "../../contracts/interfaces/INoxCompute.sol";
import {TestHelper} from "../utils/TestHelper.sol";

contract NoxCompute_PaymentTest is Test {
    address owner = makeAddr("owner");
    address gateway = vm.addr(123456789);
    NoxCompute noxCompute;

    address app = makeAddr("app");
    address sponsor = makeAddr("sponsor");

    function setUp() public {
        noxCompute = TestHelper.deploy(owner, gateway);
    }

    // ============ setSponsor ============

    function test_SetSponsor() public {
        vm.expectEmit(address(noxCompute));
        emit INoxCompute.SponsorSet(app, sponsor);
        vm.prank(app);
        noxCompute.setSponsor(sponsor);

        _assertSponsorState(app, sponsor, INoxCompute.SponsorStatus.PENDING);
    }

    function test_RevertWhen_SetSponsor_ZeroAddress() public {
        vm.expectRevert(INoxCompute.InvalidZeroAddress.selector);
        vm.prank(app);
        noxCompute.setSponsor(address(0));
    }

    function test_SetSponsor_OverwritesExisting() public {
        address firstSponsor = makeAddr("firstSponsor");
        vm.prank(app);
        noxCompute.setSponsor(firstSponsor);
        _assertSponsorState(app, firstSponsor, INoxCompute.SponsorStatus.PENDING);

        address secondSponsor = makeAddr("secondSponsor");
        vm.prank(app);
        noxCompute.setSponsor(secondSponsor);
        _assertSponsorState(app, secondSponsor, INoxCompute.SponsorStatus.PENDING);
    }

    function test_SetSponsor_IndependentApps() public {
        address app1 = makeAddr("app1");
        address app2 = makeAddr("app2");
        address sponsor1 = makeAddr("sponsor1");
        address sponsor2 = makeAddr("sponsor2");

        vm.prank(app1);
        noxCompute.setSponsor(sponsor1);
        vm.prank(app2);
        noxCompute.setSponsor(sponsor2);

        _assertSponsorState(app1, sponsor1, INoxCompute.SponsorStatus.PENDING);
        _assertSponsorState(app2, sponsor2, INoxCompute.SponsorStatus.PENDING);
    }

    function test_SetSponsor_SameSponsorMultipleApps() public {
        address app1 = makeAddr("app1");
        address app2 = makeAddr("app2");

        vm.prank(app1);
        noxCompute.setSponsor(sponsor);
        vm.prank(app2);
        noxCompute.setSponsor(sponsor);
        _assertSponsorState(app1, sponsor, INoxCompute.SponsorStatus.PENDING);
        _assertSponsorState(app2, sponsor, INoxCompute.SponsorStatus.PENDING);

        vm.startPrank(sponsor);
        noxCompute.approveSponsorship(app1);
        noxCompute.approveSponsorship(app2);
        vm.stopPrank();

        _assertSponsorState(app1, sponsor, INoxCompute.SponsorStatus.APPROVED);
        _assertSponsorState(app2, sponsor, INoxCompute.SponsorStatus.APPROVED);
    }

    // ============ approveSponsorship ============

    function test_ApproveSponsorship() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);

        vm.expectEmit(address(noxCompute));
        emit INoxCompute.SponsorshipApproved(app, sponsor);
        vm.prank(sponsor);
        noxCompute.approveSponsorship(app);

        _assertSponsorState(app, sponsor, INoxCompute.SponsorStatus.APPROVED);
    }

    function test_RevertWhen_ApproveSponsorship_UnauthorizedSponsor() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);

        address unauthorizedSponsor = makeAddr("unauthorizedSponsor");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, unauthorizedSponsor)
        );
        vm.prank(unauthorizedSponsor);
        noxCompute.approveSponsorship(app);
    }

    function test_RevertWhen_ApproveSponsorship_NotPending() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);
        vm.prank(sponsor);
        noxCompute.approveSponsorship(app);

        // already approved — status is no longer PENDING
        vm.expectRevert(abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, sponsor));
        vm.prank(sponsor);
        noxCompute.approveSponsorship(app);
    }

    // ============ revokeSponsorship ============

    function test_RevokeSponsorship() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);
        vm.prank(sponsor);
        noxCompute.approveSponsorship(app);

        vm.expectEmit(address(noxCompute));
        emit INoxCompute.SponsorshipRevoked(app, sponsor);
        vm.prank(sponsor);
        noxCompute.revokeSponsorship(app);

        _assertSponsorState(app, address(0), INoxCompute.SponsorStatus.UNSET);
    }

    function test_RevokeSponsorship_WhilePending() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);

        vm.prank(sponsor);
        noxCompute.revokeSponsorship(app);

        _assertSponsorState(app, address(0), INoxCompute.SponsorStatus.UNSET);
    }

    function test_RevertWhen_RevokeSponsorship_UnauthorizedSponsor_WhilePending() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);

        address unauthorizedSponsor = makeAddr("unauthorizedSponsor");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, unauthorizedSponsor)
        );
        vm.prank(unauthorizedSponsor);
        noxCompute.revokeSponsorship(app);
    }

    function test_RevertWhen_RevokeSponsorship_UnauthorizedSponsor_WhileApproved() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);
        vm.prank(sponsor);
        noxCompute.approveSponsorship(app);

        address unauthorizedSponsor = makeAddr("unauthorizedSponsor");
        vm.expectRevert(
            abi.encodeWithSelector(INoxCompute.UnauthorizedSender.selector, unauthorizedSponsor)
        );
        vm.prank(unauthorizedSponsor);
        noxCompute.revokeSponsorship(app);
    }

    // ============ sponsor getter ============

    function test_Sponsor_DefaultUnset() public view {
        _assertSponsorState(app, address(0), INoxCompute.SponsorStatus.UNSET);
    }

    // ============ invariants ============

    function test_Invariant_AfterSetSponsor_StatusIsPending() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);

        (, INoxCompute.SponsorStatus status) = noxCompute.sponsor(app);
        assertTrue(status == INoxCompute.SponsorStatus.PENDING);
    }

    function test_Invariant_AfterApprove_StatusIsApproved() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);
        vm.prank(sponsor);
        noxCompute.approveSponsorship(app);

        (, INoxCompute.SponsorStatus status) = noxCompute.sponsor(app);
        assertTrue(status == INoxCompute.SponsorStatus.APPROVED);
    }

    function test_Invariant_AfterRevoke_SponsorIsZeroAndStatusIsUnset() public {
        vm.prank(app);
        noxCompute.setSponsor(sponsor);
        vm.prank(sponsor);
        noxCompute.revokeSponsorship(app);

        (address actualSponsor, INoxCompute.SponsorStatus status) = noxCompute.sponsor(app);
        assertEq(actualSponsor, address(0));
        assertTrue(status == INoxCompute.SponsorStatus.UNSET);
    }

    // ============ helpers ============

    function _assertSponsorState(
        address _app,
        address expectedSponsor,
        INoxCompute.SponsorStatus expectedStatus
    ) internal view {
        (address actualSponsor, INoxCompute.SponsorStatus actualStatus) = noxCompute.sponsor(_app);
        assertEq(actualSponsor, expectedSponsor);
        assertEq(uint8(actualStatus), uint8(expectedStatus));
    }
}
