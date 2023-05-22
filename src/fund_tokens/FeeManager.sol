// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title FeeManager
 * @notice This contract provides functionality to manage fees.
 * @dev It allows to add, view, and update fees for different accounts.
 */
contract FeeManager {
    // Structure representing a fee with amount, price and timestamp of creation.
    struct Fee {
        uint8 fee; // Fee amount.
        uint256 feeId; // Id of the fee.
        uint256 price; // Price at the time of fee imposition.
        uint256 timestamp; // Timestamp when the fee was imposed.
    }

    // Array to store all fees.
    Fee[] public fees;
    mapping(address => mapping(uint256 => bool)) public paidFees;

    /* ========== MUTATIVE ========== */

    // @todo allow users to pay their fees
    // for (uint32 i = lastFeeIndex[account]; i < feeCount; i++) {
    //     Fee memory fee = fees[i];
    //     uint256 snapshotBalance = snapshotBalances[account][i];
    //     uint256 charge = fee.mgtFee * snapshotBalance / fee.price;
    //     balance -= charge;
    // }
    // Maybe emit event with vv
    //     // Structure representing fees associated with an account.
    // struct PaidFees {
    //     uint256 amount; // Amount of fee.
    //     uint32 id; // Id of the fee.
    //     uint256 time; // Timestamp when the fee was paid.   
    //     uint8 status; // Status of fee payment (0 for requested, 1 for paid).
    // }

    /* ========== VIEW FUNCTIONS ========== */

    /* ========== INTERNAL ========== */

    /**
     * @dev Adds a new fee to the fees array.
     * @param fee Fee amount.
     * @param price Price at the time of fee imposition.
     * @param timestamp When the fee was imposed.
     */
    function _addFee(uint8 fee, uint256 id, uint256 price, uint256 timestamp) internal {
        fees.push(Fee(fee, id, price, timestamp));
    }

    /**
     * @dev Marks a specific fee as paid for an account.
     * @param account Account for which to mark the fee as paid.
     * @param feeId ID of the fee to mark as paid.
     */
    function _markFeeAsPaid(address account, uint256 feeId) internal {
        paidFees[account][feeId] = true;
    }
}
