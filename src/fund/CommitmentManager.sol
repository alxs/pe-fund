// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "../interfaces/IFundToken.sol";

/**
 * @title CommitmentManager
 * @notice This contract is responsible for managing commitments in a fund context.
 */
contract CommitmentManager {
    // Structure to store commitment data.
    struct Commit {
        uint256 amount;
        CommitState status;
    }

    // Define constants for different commitment statuses.
    enum CommitState {
        COMMIT_NONE,
        COMMIT_PENDING,
        COMMIT_APPROVED,
        COMMIT_CANCELLED,
        COMMIT_REJECTED,
        COMMIT_BLOCKED
    }

    // Declare public state variables.
    uint256 public totalInPendingLpCommits;
    uint256 public totalCommittedGp;
    uint256 public totalCommittedLp;

    // Mapping to track commitments from addresses.
    mapping(address => Commit) public lpCommitments;
    address[] public gpAccounts;
    mapping(address => Commit) public gpCommitments;
    address[] public lpAccounts;

    // Event declarations.
    event LpCommitmentAdded(address indexed account, uint256 amount);
    event GpCommitmentAdded(address indexed account, uint256 amount);
    event LpCommitmentCancelled(address indexed account);
    event LpCommitmentApproved(address indexed account, uint256 amount);
    event LpCommitmentRejected(address indexed account);

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Returns the total committed amount for both GPs and LPs.
     * @return The total committed amount.
     */
    function totalCommitted() public view returns (uint256) {
        return totalCommittedGp + totalCommittedLp;
    }

    /* ========== INTERNAL ========== */

    /**
     * @dev Adds a new GP commitment.
     * @param account Address of the account.
     * @param amount Commitment amount.
     */
    function _addGpCommitment(address account, uint256 amount) internal {
        totalCommittedGp += amount;
        gpCommitments[account] = Commit(amount, CommitState.COMMIT_APPROVED);
        gpAccounts.push(account);
        emit GpCommitmentAdded(account, amount);
    }

    /**
     * @dev Sets an LP commitment for an account. If the commitment already exists,
     *      it updates the amount and resets its status.
     * @param account Address of the account.
     * @param amount Commitment amount.
     */
    function _setLpCommitment(address account, uint256 amount) internal {
        Commit storage commit = lpCommitments[account];
        if (commit.status != CommitState.COMMIT_NONE && commit.status != CommitState.COMMIT_BLOCKED) {
            totalInPendingLpCommits -= commit.amount;
        }

        if (commit.status == CommitState.COMMIT_NONE) {
            lpCommitments[account] = Commit(amount, CommitState.COMMIT_PENDING);
            lpAccounts.push(account);
        } else {
            commit.amount = amount;
            commit.status = CommitState.COMMIT_PENDING;
        }

        totalInPendingLpCommits += amount;
        emit LpCommitmentAdded(account, amount);
    }

    /**
     * @dev Cancels an existing LP commitment.
     * @param account Address of the account.
     */
    function _cancelLpCommitment(address account) internal {
        Commit storage commit = lpCommitments[account];
        require(commit.status == CommitState.COMMIT_PENDING, "Too late to cancel");

        commit.status = CommitState.COMMIT_CANCELLED;

        totalInPendingLpCommits -= commit.amount;
        emit LpCommitmentCancelled(account);
    }

    /**
     * @dev Approves multiple LP commitments.
     * @param accounts Array of account addresses to approve.
     */
    function _approveLpCommitments(address[] calldata accounts, IFundToken lpCommitToken, uint256 price) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            Commit storage commit = lpCommitments[accounts[i]];
            require(commit.status == CommitState.COMMIT_PENDING, "Commit not allowed");
            commit.status = CommitState.COMMIT_APPROVED;

            totalCommittedLp += commit.amount;
            lpCommitToken.mint(accounts[i], commit.amount / price);
            emit LpCommitmentApproved(accounts[i], commit.amount);
        }
    }

    /**
     * @dev Rejects multiple LP commitments.
     * @param accounts Array of account addresses to reject.
     */
    function _rejectLpCommitments(address[] calldata accounts) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            Commit storage commit = lpCommitments[accounts[i]];
            require(commit.status == CommitState.COMMIT_PENDING, "Commitment must be pending");

            commit.status = CommitState.COMMIT_REJECTED;
            emit LpCommitmentRejected(accounts[i]);
        }
    }
}
