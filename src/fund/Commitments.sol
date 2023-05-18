// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title Commitments
 * @dev This contract implements a functionality similar to the given Rust smart contract.
 */
contract Commitments {
    // Struct to store commitment data
    struct Commit {
        uint256 amount;
        uint256 timestamp;
        uint8 status;
    }

    // Constants
    uint8 constant COMMIT_PENDING = 0x01;
    uint8 constant COMMIT_APPROVED = 0x02;
    uint8 constant COMMIT_CANCELLED = 0x04;
    uint8 constant COMMIT_REJECTED = 0x08;
    uint8 constant COMMIT_BLOCKED = 0x10;

    // Variables
    uint256 public totalInterest;
    uint256 public totalCommittedGp;
    uint256 public totalCommittedLp;
    uint256 public blockSize;
    uint256 public price;
    IERC20 public lpToken;

    // Commitments mapping
    mapping(address => Commit) public lpCommitments;
    mapping(address => Commit) public gpCommitments;

    // Events
    event LpCommitmentAdded(address indexed account, uint256 amount, uint256 timestamp);
    event GpCommitmentAdded(address indexed account, uint256 amount, uint256 timestamp);
    event LpCommitmentCancelled(address indexed account, uint256 timestamp);
    event LpCommitmentApproved(address indexed account, uint256 amount, uint256 timestamp);
    event LpCommitmentRejected(address indexed account, uint256 timestamp);

    /**
     * @dev Constructor sets the initial values.
     * @param _blockSize The initial block size.
     * @param _price The initial price.
     * @param _lpToken The address of the LP token.
     */
    constructor(uint256 _blockSize, uint256 _price, IERC20 _lpToken) {
        blockSize = _blockSize;
        price = _price;
        lpToken = _lpToken;
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
     * @dev Adds a GP commitment.
     * @param _account The address of the account.
     * @param _amount The amount of the commitment.
     * @param _time The timestamp of the commitment.
     */

    function addGpCommitment(address _account, uint256 _amount, uint256 _time) internal {
        totalCommittedGp = totalCommittedGp + _amount;
        gpCommitments[_account] = Commit(_amount, _time, COMMIT_APPROVED);
        emit GpCommitmentAdded(_account, _amount, _time);
    }

    /**
     * @dev Adds an LP commitment.
     * @param _account The address of the account.
     * @param _amount The amount of the commitment.
     * @param _time The timestamp of the commitment.
     */
    function addLpCommitment(address _account, uint256 _amount, uint256 _time) internal {
        Commit storage commit = lpCommitments[_account];
        if (commit.status != 0 && commit.status != COMMIT_BLOCKED) {
            totalInterest = totalInterest - commit.amount;
        }

        if (commit.status == 0) {
            lpCommitments[_account] = Commit(_amount, _time, COMMIT_PENDING);
        } else {
            commit.amount = _amount;
            commit.timestamp = _time;
            commit.status = COMMIT_PENDING;
        }

        totalInterest = totalInterest + _amount;
        emit LpCommitmentAdded(_account, _amount, _time);
    }

    /**
     * @dev Cancels an LP commitment.
     * @param _account The address of the account.
     * @param _time The timestamp of the cancellation.
     */
    function cancelLpCommitment(address _account, uint256 _time) internal {
        Commit storage commit = lpCommitments[_account];
        require(commit.status & COMMIT_PENDING == COMMIT_PENDING, "Too late to cancel");

        commit.timestamp = _time;
        commit.status = COMMIT_CANCELLED;

        totalInterest = totalInterest - commit.amount;
        emit LpCommitmentCancelled(_account, _time);
    }

    /**
     * @dev Approves LP commitments.
     * @param _accounts The addresses of the accounts to approve.
     * @param _time The timestamp of the approval.
     */
    function approveLpCommitments(address[] calldata _accounts, uint256 _time) internal {
        for (uint256 i = 0; i < _accounts.length; i++) {
            Commit storage commit = lpCommitments[_accounts[i]];
            require(commit.status & COMMIT_PENDING == COMMIT_PENDING, "Commit not allowed");

            commit.timestamp = _time;
            commit.status = COMMIT_APPROVED;

            totalCommittedLp = totalCommittedLp + commit.amount;
            lpToken.transfer(_accounts[i], commit.amount / price);
            emit LpCommitmentApproved(_accounts[i], commit.amount, _time);
        }
    }

    /**
     * @dev Rejects LP commitments.
     * @param _accounts The addresses of the accounts to reject.
     * @param _time The timestamp of the rejection.
     */
    function rejectLpCommitments(address[] calldata _accounts, uint256 _time) internal {
        for (uint256 i = 0; i < _accounts.length; i++) {
            Commit storage commit = lpCommitments[_accounts[i]];
            require(commit.status & COMMIT_PENDING == COMMIT_PENDING, "Commit not allowed");

            commit.timestamp = _time;
            commit.status = COMMIT_REJECTED;
            emit LpCommitmentRejected(_accounts[i], _time);
        }
    }
}
