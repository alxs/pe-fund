// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Redemption Contract
 * @notice Contract that allows managing and processing redemption operations
 */
contract Redemptions {
    /**
     * @title RedemptionStatus
     * @dev Enum representing the various states of redemption process.
     * Each member of the enum corresponds to an integer, starting from 0.
     * The members are:
     * - REDEMPTION_PENDING: 0, signifies the initial state of a redemption request
     * - REDEMPTION_APPROVED: 1, signifies the redemption request has been approved
     * - REDEMPTION_CANCELLED: 2, signifies the redemption request has been cancelled by the user
     * - REDEMPTION_REJECT: 3, signifies the redemption request has been rejected
     * - REDEMPTION_BLOCKED: 4, signifies the redemption process has been blocked due to some condition
     */
    enum RedemptionStatus {
        REDEMPTION_PENDING,
        REDEMPTION_APPROVED,
        REDEMPTION_CANCELLED,
        REDEMPTION_REJECT,
        REDEMPTION_BLOCKED
    }

    struct RedemptionData {
        address account;
        uint256 amount;
        uint32 time;
        RedemptionStatus status;
    }

    uint256 public totalRedemptions;
    mapping(address => RedemptionData) public redemptions;

    /**
     * @notice Add a new redemption request
     * @param account The address requesting the redemption
     * @param amount The amount to be redeemed
     * @param time The timestamp when the redemption request was made
     */
    function addRedemption(address account, uint256 amount, uint32 time) public virtual {
        require(redemptions[account].status != RedemptionStatus.REDEMPTION_BLOCKED, "Commit Not Allowed");
        redemptions[account] = RedemptionData(account, amount, time, RedemptionStatus.REDEMPTION_PENDING);
    }

    /**
     * @notice Cancel an existing redemption request
     * @param account The address requesting the cancellation
     * @param time The timestamp when the redemption cancellation request was made
     */
    function cancelRedemption(address account, uint32 time) public virtual {
        _updateRedemption(account, time, RedemptionStatus.REDEMPTION_CANCELLED);
    }

    /**
     * @notice Approve an existing redemption request
     * @param account The address for which the redemption request is approved
     * @param time The timestamp when the redemption approval was made
     */
    function approveRedemption(address account, uint32 time) public virtual {
        _updateRedemption(account, time, RedemptionStatus.REDEMPTION_APPROVED);
        totalRedemptions += redemptions[account].amount;
    }

    /**
     * @notice Reject an existing redemption request
     * @param account The address for which the redemption request is rejected
     * @param time The timestamp when the redemption rejection was made
     */
    function rejectRedemption(address account, uint32 time) public virtual {
        _updateRedemption(account, time, RedemptionStatus.REDEMPTION_REJECT);
    }

    /**
     * @dev This internal function is used to update the status of a redemption request.
     *      It sets the time and status for the redemption associated with the given account.
     *      The function requires that the current redemption status is REDEMPTION_PENDING.
     * @param account The account whose redemption is being updated.
     * @param time The new time for the redemption.
     * @param newStatus The new status for the redemption.
     */
    function _updateRedemption(address account, uint32 time, RedemptionStatus newStatus) private {
        // Load the redemption from storage, this is a reference to the state variable
        RedemptionData storage redemption = redemptions[account];

        // Ensure the current status of the redemption is REDEMPTION_PENDING
        require(redemption.status == RedemptionStatus.REDEMPTION_PENDING, "Redemption Not Allowed");

        // Update the redemption's time and status
        redemption.time = time;
        redemption.status = newStatus;
    }
}
