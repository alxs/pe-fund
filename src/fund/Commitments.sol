// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IFundToken.sol";

/**
 * @title Commitments
 * @notice Implements a commitment functionality similar to a specified Rust smart contract.
 */
contract Commitments {
    // Structure to store commitment data.
    struct Commit {
        uint256 amount;
        uint256 timestamp;
        uint8 status;
    }

    // Define constants for different commitment statuses.
    uint8 constant COMMIT_PENDING = 0x01;
    uint8 constant COMMIT_APPROVED = 0x02;
    uint8 constant COMMIT_CANCELLED = 0x04;
    uint8 constant COMMIT_REJECTED = 0x08;
    uint8 constant COMMIT_BLOCKED = 0x10;

    // Declare public state variables.
    uint256 public totalInterest;
    uint256 public totalCommittedGp;
    uint256 public totalCommittedLp;
    uint256 public blockSize;
    uint256 public price;

    // Mapping to track commitments from addresses.
    mapping(address => Commit) public lpCommitments;
    address[] public gpAccounts;
    mapping(address => Commit) public gpCommitments;
    address[] public lpAccounts;

    // Event declarations.
    event LpCommitmentAdded(address indexed account, uint256 amount, uint256 timestamp);
    event GpCommitmentAdded(address indexed account, uint256 amount, uint256 timestamp);
    event LpCommitmentCancelled(address indexed account, uint256 timestamp);
    event LpCommitmentApproved(address indexed account, uint256 amount, uint256 timestamp);
    event LpCommitmentRejected(address indexed account, uint256 timestamp);

    /**
     * @dev Sets initial values for block size and price.
     * @param blockSize_ Initial block size.
     * @param price_ Initial price.
     */
    constructor(uint256 blockSize_, uint256 price_) {
        blockSize = blockSize_;
        price = price_;
        totalInterest = 0;
        totalCommittedGp = 0;
        totalCommittedLp = 0;
    }

    /**
     * @dev Returns the total interest.
     * @return The total interest.
     */
    function getTotalInterest() external view returns (uint256) {
        return totalInterest;
    }

    /**
     * @dev Returns the total committed amount for both GPs and LPs.
     * @return The total committed amount.
     */
    function totalCommitted() external view returns (uint256) {
        return totalCommittedGp + totalCommittedLp;
    }

    /**
     * @dev Returns the total committed amount for GPs.
     * @return The total committed amount for GPs.
     */
    function getTotalCommittedGP() external view returns (uint256) {
        return totalCommittedGp;
    }

    /**
     * @dev Returns the total committed amount for LPs.
     * @return The total committed amount for LPs.
     */
    function getTotalCommittedLP() external view returns (uint256) {
        return totalCommittedLp;
    }

    /**
     * @dev Adds a new GP commitment.
     * @param account Address of the account.
     * @param amount Commitment amount.
     * @param time Commitment timestamp.
     */
    function _addGpCommitment(address account, uint256 amount, uint256 time) internal {
        totalCommittedGp += amount;
        gpCommitments[account] = Commit(amount, time, COMMIT_APPROVED);
        gpAccounts.push(account);
        emit GpCommitmentAdded(account, amount, time);
    }

    /**
     * @dev Adds a new LP commitment.
     * @param account Address of the account.
     * @param amount Commitment amount.
     * @param time Commitment timestamp.
     */
    function _addLpCommitment(address account, uint256 amount, uint256 time) internal {
        Commit storage commit = lpCommitments[account];
        if (commit.status != 0 && commit.status != COMMIT_BLOCKED) {
            totalInterest -= commit.amount;
        }

        if (commit.status == 0) {
            lpCommitments[account] = Commit(amount, time, COMMIT_PENDING);
            lpAccounts.push(account);
        } else {
            commit.amount = amount;
            commit.timestamp = time;
            commit.status = COMMIT_PENDING;
        }

        totalInterest += amount;
        emit LpCommitmentAdded(account, amount, time);
    }

    /**
     * @dev Cancels an existing LP commitment.
     * @param account Address of the account.
     * @param time Cancellation timestamp.
     */
    function _cancelLpCommitment(address account, uint256 time) internal {
        // @todo this should probably by callable by the user
        Commit storage commit = lpCommitments[account];
        require(commit.status & COMMIT_PENDING == COMMIT_PENDING, "Too late to cancel");

        commit.timestamp = time;
        commit.status = COMMIT_CANCELLED;

        totalInterest -= commit.amount;
        emit LpCommitmentCancelled(account, time);
    }

    /**
     * @dev Approves multiple LP commitments.
     * @param accounts Array of account addresses to approve.
     * @param time Approval timestamp.
     */
    function _approveLpCommitments(address[] calldata accounts, uint256 time, IFundToken lpCommitToken) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            Commit storage commit = lpCommitments[accounts[i]];
            require(commit.status == COMMIT_PENDING, "Commit not allowed");
            commit.timestamp = time;
            commit.status = COMMIT_APPROVED;

            totalCommittedLp += commit.amount;
            lpCommitToken.mint(accounts[i], commit.amount / price);
            emit LpCommitmentApproved(accounts[i], commit.amount, time);
        }
    }

    /**
     * @dev Rejects multiple LP commitments.
     * @param accounts Array of account addresses to reject.
     * @param time Rejection timestamp.
     */
    function _rejectLpCommitments(address[] calldata accounts, uint256 time) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            Commit storage commit = lpCommitments[accounts[i]];
            require(commit.status & COMMIT_PENDING == COMMIT_PENDING, "Commit not allowed");

            commit.timestamp = time;
            commit.status = COMMIT_REJECTED;
            emit LpCommitmentRejected(accounts[i], time);
        }
    }
}
