// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Common} from "./Common.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Payment
 * @notice Pay-per-task USDC billing and sponsorship management.
 * @dev Hardcoded pricing constants. No on-chain price setter — price changes require a contract upgrade.
 *
 * Sponsorship setup (called by app contracts and sponsors, not by Nox admin):
 *   app calls setSponsor(sponsorAddr)    → status: PENDING
 *   sponsor calls approveSponsorship(app) → status: APPROVED
 *   sponsor calls revokeSponsorship(app)  → clears sponsor (address(0), UNSET)
 */
abstract contract Payment is Common {
    // TODO: set final values before deployment
    address public constant USDC = address(0);
    address public constant TREASURY = address(0);
    uint256 public constant CU_PER_OPERATION = 1;
    uint256 public constant CU_PRICE_USDC = 0; // e.g. 1e4 = 0.01 USDC (6 decimals)

    /// @inheritdoc INoxCompute
    function setSponsor(address newSponsor) external override {
        require(newSponsor != address(0), InvalidZeroAddress());
        _setSponsorAndStatus(msg.sender, newSponsor, SponsorStatus.PENDING);
        emit SponsorSet(msg.sender, newSponsor);
    }

    /// @inheritdoc INoxCompute
    function approveSponsorship(address app) external override {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        Sponsor memory s = $.sponsors[app];
        require(
            s.sponsor == msg.sender && s.status == SponsorStatus.PENDING,
            UnauthorizedSender(msg.sender)
        );
        _setSponsorAndStatus(app, msg.sender, SponsorStatus.APPROVED);
        emit SponsorshipApproved(app, msg.sender);
    }

    /// @inheritdoc INoxCompute
    function revokeSponsorship(address app) external override {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        require($.sponsors[app].sponsor == msg.sender, UnauthorizedSender(msg.sender));
        _setSponsorAndStatus(app, address(0), SponsorStatus.UNSET);
        emit SponsorshipRevoked(app, msg.sender);
    }

    /// @inheritdoc INoxCompute
    function sponsor(address app) external view override returns (address, SponsorStatus) {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        return ($.sponsors[app].sponsor, $.sponsors[app].status);
    }

    function _processPayment(address /*caller*/, Operator /*operator*/) internal virtual override {
        // TODO: implement payment logic
    }

    /// @dev Always use this to update sponsor state to guarantee both fields stay in sync.
    function _setSponsorAndStatus(
        address app,
        address newSponsor,
        SponsorStatus newStatus
    ) private {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        $.sponsors[app] = Sponsor({sponsor: newSponsor, status: newStatus});
    }
}
