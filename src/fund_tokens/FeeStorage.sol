// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title FeeManager
 * @notice This contract provides functionality to manage fees.
 * @dev It allows to add, view, and update fees for different accounts.
 */
contract FeeStorage {
    // Structure representing a fee with ID, amount, price and timestamp of creation.
    struct Fee {
        uint8 fee; // Fee amount.
        uint256 price; // Price at the time of fee imposition.
        uint32 timestamp; // Timestamp when the fee was imposed.
    }

    // Map to store all fees.
    mapping(uint16 => Fee) private fees;
    uint16 internal totalFees;

    /**
     * @dev Adds a new fee to the fees array.
     * @param fee Fee amount.
     * @param price Price at the time of fee imposition.
     * @param timestamp When the fee was imposed.
     */
    function _addFee(uint8 fee, uint16 id, uint256 price, uint32 timestamp) internal {
        require(fees[id].timestamp == 0, "Fee already set");

        fees[id] = Fee(fee, price, timestamp);
        ++totalFees;
    }

    /**
     * @dev Gets the fee from the fees array using id.
     * @param id The id to use for lookup in the fees array.
     * @return Fee The fee structure associated with the id.
     */
    function _getFee(uint16 id) internal view returns (Fee storage) {
        return fees[id];
    }
}
