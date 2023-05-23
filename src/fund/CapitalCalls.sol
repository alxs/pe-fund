// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IFundToken.sol";

/**
 * @title CapitalCalls
 * @notice This contract is responsible for managing "capital calls" in a fund context.
 */
contract CapitalCalls {
    // Enum to define the account type: General Partner (GP) or Limited Partner (LP)
    enum AccountType {
        GP,
        LP
    }

    // Struct to represent a capital call
    struct CapitalCall {
        uint256 amount; // Amount of the capital call
        string drawdownType; // Type of drawdown as a string
        uint32 time; // Timestamp when the capital call was created
    }

    // Struct to represent an account's capital call
    struct AccountCapitalCall {
        uint256 amount; // Amount of the capital call for the account
        uint32 timestamp; // Timestamp when the capital call was handled
        AccountType accountType; // Type of the account (GP or LP)
        bool isDone; // Flag indicating if the capital call is done
        bool hasFailed; // Flag indicating if the capital call has failed
    }

    CapitalCall[] public capitalCalls; // Mapping to store capital calls
    // Mapping to store capital calls per account
    mapping(address => mapping(uint16 => AccountCapitalCall)) public accountCapitalCalls;
    uint256 public totalCalled = 0; // Total amount of capital called

    event CapitalCallAdded(uint256 callId, uint256 amount, string drawdownType, uint32 time);
    event AccountCapitalCallDone(uint256 callId, address account);
    event AccountCapitalCallFailed(uint256 callId, address account);

    /**
     * @notice This function allows to add a new capital call.
     * @dev A new CapitalCall struct is created and stored in the capitalCalls mapping.
     * @param amount The desired amount of the capital call.
     * @param drawdownType The type of drawdown.
     * @param time The creation timestamp of the capital call.
     * @return callId The ID of the newly created capital call.
     */
    function _addCapitalCall(uint256 amount, string memory drawdownType, uint32 time) internal returns (uint16) {
        capitalCalls.push(CapitalCall(amount, drawdownType, time));

        uint16 callId = uint16(capitalCalls.length - 1);
        emit CapitalCallAdded(callId, amount, drawdownType, time);
        return callId;
    }

    /**
     * @notice This function handles a failed capital call.
     * @dev Sets the capital call as failed and updates the timestamp.
     * @param callId The ID of the capital call.
     * @param account The account address participating in the capital call.
     */
    function _capitalCallFailed(uint16 callId, address account) internal {
        AccountCapitalCall storage acc = accountCapitalCalls[account][callId];
        require(acc.accountType == AccountType.GP || acc.accountType == AccountType.LP, "Invalid account type.");

        acc.hasFailed = true;
        acc.timestamp = uint32(block.timestamp);

        emit AccountCapitalCallFailed(callId, account);
    }

    /**
     * @notice This function adds an account capital call.
     * @dev A new AccountCapitalCall struct is created and added to the accountCapitalCalls mapping.
     * @param callId The ID of the capital call.
     * @param account The account address participating in the capital call.
     * @param amount The amount for the account's capital call.
     * @param accountType The type of the account (GP or LP).
     */
    function _addAccountCapitalCall(uint16 callId, address account, uint256 amount, AccountType accountType) internal {
        require(accountType == AccountType.GP || accountType == AccountType.LP, "Invalid account type.");

        accountCapitalCalls[account][callId] = AccountCapitalCall({
            amount: amount,
            timestamp: 0,
            accountType: accountType,
            isDone: false,
            hasFailed: false
        });
    }
}
