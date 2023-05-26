// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Redemption Contract
 * @notice Contract that allows managing and processing redemption operations
 * @dev P2. @todo no value transfer
 */
contract RedemptionManager {
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

    // Redemption entry.
    struct RedemptionData {
        address account;
        uint256 amount;
        RedemptionStatus status;
    }

    // Mapping from accounts to redemption entry.
    mapping(address => RedemptionData) public redemptions;
    uint256 public totalRedemptions;

    // Event declarations.
    event RedemptionAdded(address account, uint256 amount);
    event RedemptionApproved(address account);
    event RedemptionCancelled(address account);
    event RedemptionRejected(address account);

    /* ========== INTERNAL ========== */

    /**
     * @notice Add a new redemption request
     * @param account The address requesting the redemption
     * @param amount The amount to be redeemed
     */
    function _addRedemption(address account, uint256 amount) internal {
        require(redemptions[account].status != RedemptionStatus.REDEMPTION_BLOCKED, "Redemption Not Allowed");
        redemptions[account] = RedemptionData(account, amount, RedemptionStatus.REDEMPTION_PENDING);
        emit RedemptionAdded(account, amount);
    }

    /**
     * @notice Approve an existing redemption request
     * @param account The address for which the redemption request is approved
     */
    function _approveRedemption(address account) internal {
        _updateRedemption(account, RedemptionStatus.REDEMPTION_APPROVED);
        totalRedemptions += redemptions[account].amount;
        emit RedemptionApproved(account);
    }

    /**
     * @notice Cancel an existing redemption request
     * @param account The address requesting the cancellation
     */
    function _cancelRedemption(address account) internal {
        _updateRedemption(account, RedemptionStatus.REDEMPTION_CANCELLED);
        emit RedemptionCancelled(account);
    }

    /**
     * @notice Reject an existing redemption request
     * @param account The address for which the redemption request is rejected
     */
    function _rejectRedemption(address account) internal {
        _updateRedemption(account, RedemptionStatus.REDEMPTION_REJECT);
        emit RedemptionRejected(account);
    }

    /* ========== PRIVATE ========== */

    /**
     * @dev This internal function is used to update the status of a redemption request.
     *      It sets the time and status for the redemption associated with the given account.
     *      The function requires that the current redemption status is REDEMPTION_PENDING.
     * @param account The account whose redemption is being updated.
     * @param newStatus The new status for the redemption.
     */
    function _updateRedemption(address account, RedemptionStatus newStatus) private {
        // Load the redemption from storage, this is a reference to the state variable
        RedemptionData storage redemption = redemptions[account];

        // Ensure the current status of the redemption is REDEMPTION_PENDING
        require(redemption.status == RedemptionStatus.REDEMPTION_PENDING, "No Pending Redemption");

        // Update the redemption's status
        redemption.status = newStatus;
    }
}
