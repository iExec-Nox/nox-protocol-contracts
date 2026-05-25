// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.35;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Common} from "./Common.sol";

/**
 * @title Payment
 * @notice Billing enforcement for confidential operations.
 * @dev Pricing constants are hardcoded; changes require a contract upgrade.
 *      Set CU_PER_OPERATION to 0 to disable billing entirely (e.g. local dev).
 *
 * Billing priority per operation:
 *   1. App linked to an active license with remaining quota → pay with license quota
 *   2. App has an approved sponsor and CU_PRICE_USDC > 0    → pay with sponsor's USDC
 *   3. Neither                                              → revert NoApprovedSponsor
 */
abstract contract Payment is Common {
    using SafeERC20 for IERC20;

    // TODO: set final values before deployment
    address public constant USDC = address(0);
    address public constant TREASURY = address(0);
    uint24 public constant CU_PRICE_USDC = 0; // e.g. 1e4 = 0.01 USDC (6 decimals)
    // Payment kill switch: set to 0 to disable payment.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint8 public immutable CU_PER_OPERATION;

    constructor(uint8 cuPerOperation) {
        CU_PER_OPERATION = cuPerOperation;
    }

    /**
     * @dev Charges the caller for one operation. No-op if payment is disabled.
     * Try license payment first, then sponsor payment, and revert if neither is available.
     * @param caller address of the app calling the compute function
     */
    function _processPayment(address caller, Operator /*operator*/) internal virtual override {
        if (CU_PER_OPERATION == 0) {
            return;
        }
        NoxComputeStorage storage $ = _getNoxComputeStorage();
        if (_payWithLicense($, caller)) {
            return;
        }
        _payWithSponsor($, caller);
    }

    /**
     * @dev Attempts license payment. Returns true if the caller's app is linked to an active
     * license with remaining quota and the quota was deducted, false otherwise.
     * @param caller address of the app calling the compute function
     */
    function _payWithLicense(NoxComputeStorage storage $, address caller) private returns (bool) {
        address licenseOwner = $.appLicensors[caller];
        if (licenseOwner == address(0)) {
            return false;
        }
        License memory license = $.licenses[licenseOwner];
        if (license.expirationDate <= block.timestamp) {
            return false;
        }
        // TODO: add monthly quota reset once date utilities are available
        if (uint48(license.consumedQuota) + CU_PER_OPERATION > license.monthlyQuota) {
            return false;
        }
        // Safe: consumedQuota + CU_PER_OPERATION <= monthlyQuota <= type(uint24).max
        unchecked {
            $.licenses[licenseOwner].consumedQuota = license.consumedQuota + CU_PER_OPERATION;
        }
        return true;
    }

    /**
     * @dev Charges the caller's sponsor in USDC. No-op if price in USDC is 0.
     * @param caller address of the app calling the compute function
     */
    function _payWithSponsor(NoxComputeStorage storage $, address caller) private {
        if (CU_PRICE_USDC == 0) {
            return;
        }
        Sponsor memory s = $.sponsors[caller];
        require(s.status == SponsorStatus.APPROVED, NoApprovedSponsor(caller));
        // The sponsor opted in via approveSponsorship and must grant USDC allowance
        // to this contract. Pulling from s.sponsor is the documented payment flow.
        // slither-disable-next-line arbitrary-send-erc20
        IERC20(USDC).safeTransferFrom(
            s.sponsor,
            TREASURY,
            uint256(CU_PER_OPERATION) * CU_PRICE_USDC
        );
    }
}
