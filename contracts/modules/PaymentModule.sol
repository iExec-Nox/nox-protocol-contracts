// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Common} from "./Common.sol";

/**
 * @title PaymentModule
 * @notice Pay-per-task billing: license-based quota deduction with sponsor USDC fallback.
 * @dev Hardcoded pricing constants. No on-chain price setter — price changes require a contract upgrade.
 *
 * Billing priority per operation:
 *   1. App linked to an active license with remaining quota → deduct 1 CU
 *   2. App has an approved sponsor                         → USDC.transferFrom(sponsor, TREASURY, cost)
 *   3. Neither                                             → revert NoPaymentMethod
 */
abstract contract PaymentModule is Common {
    // TODO: set final values before deployment
    address public constant USDC = address(0);
    address public constant TREASURY = address(0);
    uint24 public constant CU_PRICE_USDC = 0; // e.g. 1e4 = 0.01 USDC (6 decimals)

    // Kill switch: set to 0 to deactivate payment.
    uint8 public immutable CU_PER_OPERATION;

    constructor(uint8 cuPerOperation) {
        CU_PER_OPERATION = cuPerOperation;
    }

    function _processPayment(address caller, Operator /*operator*/) internal virtual override {
        if (CU_PER_OPERATION == 0) {
            return;
        }

        NoxComputeStorage storage $ = _getNoxComputeStorage();
        address licenseOwner = $.appLicensors[caller];

        if (licenseOwner != address(0) && _licenseActive(licenseOwner)) {
            if (_payWithLicense($.licenses[licenseOwner])) {
                return;
            }
        }

        _payWithSponsor(caller);
    }

    /// @return true if quota was available and CU was deducted, false if quota exhausted
    function _payWithLicense(License storage license) private returns (bool) {
        // TODO: add monthly quota reset once date utilities are available
        if (license.consumedQuota >= license.monthlyQuota) {
            return false;
        }
        // Safe: consumedQuota < monthlyQuota guaranteed by check above
        unchecked {
            license.consumedQuota += CU_PER_OPERATION;
        }
        return true;
    }

    function _payWithSponsor(address caller) private {
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        Sponsor memory s = $.sponsors[caller];
        require(s.status == SponsorStatus.APPROVED, NoPaymentMethod(caller));
        if (CU_PRICE_USDC > 0) {
            IERC20(USDC).transferFrom(
                s.sponsor,
                TREASURY,
                uint256(CU_PER_OPERATION) * CU_PRICE_USDC
            );
        }
    }
}
