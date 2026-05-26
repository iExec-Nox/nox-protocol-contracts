// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Common} from "./Common.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Sponsorship
 * @notice Sponsorship management: an app can declare a sponsor, the sponsor approves or revokes.
 * Sponsors pay for app operations in USDC if the app has no active license.
 *
 * Setup flow:
 *   app calls setSponsor(sponsorAddr)    → status: PENDING
 *   sponsor calls approveSponsorship(app) → status: APPROVED
 *   sponsor calls revokeSponsorship(app)  → clears sponsor (address(0), UNSET)
 */
abstract contract Sponsorship is Common {
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
