// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title FeeManager
 * @dev This contract provides functionality to manage fees.
 */
contract FeeManager {

    struct Fee {
        uint8 fee;
        uint256 price;
        uint256 timestamp;
    }

    // Struct to store account fees
    struct AccountFees {
        uint256 amount;
        uint64 time;
        uint8 status;
    }

    Fee[] private _fees;
    mapping(address => AccountFees)[] private _accountFees;

    // Fee status constants
    uint8 constant FEE_REQUESTED = 0;
    uint8 constant FEE_PAID = 1;

    /**
     * @dev Throws if account has pending fees.
     */
    modifier noPendingFee(address account) {
        for (uint256 i = 0; i <= _accountFees.length; i++) {
            require(_accountFees[i][account].status != FEE_REQUESTED, "FeeManager: Fee is pending");
        }
        _;
    }

    /**
     * @dev Initialize the contract.
     */
    constructor() {}

    /* ========== MUTATIVE ========== */

    // @todo allow users to pay their fees
    // for (uint32 i = lastFeeIndex[account]; i < feeCount; i++) {
    //     Fee memory fee = fees[i];
    //     uint256 snapshotBalance = snapshotBalances[account][i];
    //     uint256 charge = fee.mgtFee * snapshotBalance / fee.price;
    //     balance -= charge;
    // }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Returns fee information for an account.
     */
    function getAccountFees(uint256 feeId, address account) public view returns (AccountFees memory) {
        return _accountFees[feeId][account];
    }

    /**
     * @dev Returns fee information for an account.
     */
    function nextFeeId() public view returns (uint256) {
        return _fees.length;
    }

    /* ========== INTERNAL ========== */

    /**
     * @dev Adds fee for all accounts
     */
    function _addFee(uint8 fee, uint256 price, uint64 timestamp) internal {
        _fees[_fees.length] = Fee(fee, price, timestamp);
    }

    /**
     * @dev Adds fee for an account
     */
    function _addAccountFee(uint32 feeId, address account, uint256 amount, uint64 time) internal {
        _accountFees[feeId][account] = AccountFees(amount, time, FEE_REQUESTED);
    }

    /**
     * @dev Updates fee status for a list of accounts.
     */
    function _updateFeeStatus(uint256 feeId, address[] memory accounts, uint64 time, uint8 status) internal {
        for (uint256 i = 0; i < accounts.length; i++) {
            AccountFees storage fees = _accountFees[feeId][accounts[i]];
            fees.time = time;
            fees.status = status;
        }
    }
}
