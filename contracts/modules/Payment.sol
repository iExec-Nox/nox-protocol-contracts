// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Common} from "./Common.sol";
import {INoxCompute} from "../interfaces/INoxCompute.sol";

/**
 * @title Payment
 * @notice Pay-per-task USDC billing and sponsorship management.
 * @dev Hardcoded pricing constants. No on-chain price setter — price changes require a contract upgrade.
 *
 * Billing flow on each paid operation (via _processPayment):
 *   1. If caller has a valid license with remaining monthly quota → decrement quota, proceed free.
 *   2. Otherwise → transferFrom(sponsor, TREASURY, CU_PER_OPERATION * CU_PRICE_USDC).
 *
 * Sponsorship setup (called by app contracts, not by Nox admin):
 *   app calls setSponsor(sponsorAddr)    → status: PENDING
 *   sponsor calls approveSponsorship(app) → status: APPROVED
 *   sponsor calls revokeSponsorship(app)  → status: REVOKED
 */
abstract contract Payment is Common {
    // TODO: set final values before mainnet deployment
    address public constant USDC = address(0);
    address public constant TREASURY = address(0);
    uint256 public constant CU_PER_OPERATION = 1;
    uint256 public constant CU_PRICE_USDC = 0; // e.g. 1e4 = 0.01 USDC (6 decimals)

    /// @inheritdoc INoxCompute
    function setSponsor(address /*sponsor*/) external virtual override {}

    /// @inheritdoc INoxCompute
    function approveSponsorship(address /*app*/) external virtual override {}

    /// @inheritdoc INoxCompute
    function revokeSponsorship(address /*app*/) external virtual override {}

    /// @inheritdoc INoxCompute
    function sponsor(
        address /*app*/
    ) external view virtual override returns (address, SponsorStatus) {
        return (address(0), SponsorStatus.UNSET);
    }

    function _processPayment(address /*caller*/, Operator /*operator*/) internal virtual override {
        // TODO: implement payment logic
    }
}
