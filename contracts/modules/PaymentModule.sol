// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {Common} from "./Common.sol";

/**
 * @title PaymentModule
 * @notice Pay-per-task billing: license-based quota deduction with sponsor USDC fallback.
 * @dev Hardcoded pricing constants. No on-chain price setter — price changes require a contract upgrade.
 *
 * Billing priority per operation:
 *   1. App linked to an active license → deduct 1 CU from monthly quota
 *   2. App has an approved sponsor     → USDC.transferFrom(sponsor, TREASURY, cost)
 *   3. No payment method               → revert
 */
abstract contract PaymentModule is Common {
    // TODO: set final values before deployment
    address public constant USDC = address(0);
    address public constant TREASURY = address(0);
    uint256 public constant CU_PER_OPERATION = 1;
    uint256 public constant CU_PRICE_USDC = 0; // e.g. 1e4 = 0.01 USDC (6 decimals)

    function _processPayment(address /*caller*/, Operator /*operator*/) internal virtual override {
        // TODO: implement payment logic
    }
}
