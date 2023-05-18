// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ISecurityToken.sol";

/**
 * @title CapitalCalls
 * @notice Implements functionality around "capital calls" and managing them in a fund context.
 */
contract CapitalCalls {
    // An enumeration to represent the type of account: General Partner (GP) or Limited Partner (LP)
    enum AccountType {
        GP,
        LP
    }

    // A struct to represent a capital call
    struct CapitalCall {
        uint256 amount;
        string drawdownType;
        uint256 time;
        ISecurityToken gpFundToken;
        ISecurityToken lpFundToken;
    }

    // A struct to represent an account capital call
    struct AccountCapitalCall {
        uint256 amount;
        uint256 timestamp;
        AccountType accountType;
        bool isDone;
        bool hasFailed;
    }

    uint256 public totalCalled = 0;
    mapping(uint256 => CapitalCall) public capitalCalls;
    mapping(address => mapping(uint256 => AccountCapitalCall)) public accountCapitalCalls;
    uint256 public capitalCallsCount = 0;

    event CapitalCallAdded(
        uint256 callId, uint256 amount, string drawdownType, uint256 time, address gpFundToken, address lpFundToken
    );
    event AccountCapitalCallDone(uint256 callId, address account);
    event AccountCapitalCallFailed(uint256 callId, address account);

    /**
     * @notice Adds a capital call.
     * @dev Creates a new CapitalCall struct and adds it to the capitalCalls mapping.
     * @param amount The amount of the capital call.
     * @param drawdownType The drawdown type as a string.
     * @param time The timestamp of the capital call creation.
     * @param gpFundToken The address of the GP fund token contract.
     * @param lpFundToken The address of the LP fund token contract.
     * @return callId The ID of the newly created capital call.
     */
    function addCapitalCall(
        uint256 amount,
        string memory drawdownType,
        uint256 time,
        ISecurityToken gpFundToken,
        ISecurityToken lpFundToken
    ) public returns (uint256) {
        // @todo capitalCalls can probably just be an array
        capitalCalls[capitalCallsCount] = CapitalCall(amount, drawdownType, time, gpFundToken, lpFundToken);
        emit CapitalCallAdded(capitalCallsCount, amount, drawdownType, time, address(gpFundToken), address(lpFundToken));

        capitalCallsCount++;
        totalCalled++;

        return capitalCallsCount - 1;
    }

    /**
     * @notice Handles a successful capital call.
     * @dev Transfers the specified amount of tokens from the account to the contract and marks the capital call as done.
     * @param callId The ID of the capital call.
     * @param account The address of the account involved in the capital call.
     */
    function capitalCallDone(uint256 callId, address account) public {
        AccountCapitalCall storage acc = accountCapitalCalls[account][callId];
        require(acc.accountType == AccountType.GP || acc.accountType == AccountType.LP, "Invalid account type.");

        IERC20 token;
        if (acc.accountType == AccountType.GP) {
            token = capitalCalls[callId].gpFundToken;
        } else if (acc.accountType == AccountType.LP) {
            token = capitalCalls[callId].lpFundToken;
        }

        require(token.balanceOf(account) >= acc.amount, "Insufficient balance.");

        token.transferFrom(account, address(this), acc.amount);

        acc.isDone = true;
        acc.timestamp = block.timestamp;
        emit AccountCapitalCallDone(callId, account);
    }

    /**
     * @notice Handles a failed capital call.
     * @dev Marks the capital call as failed and updates the timestamp.
     * @param callId The ID of the capital call.
     * @param account The address of the account involved in the capital call.
     */
    function capitalCallFailed(uint256 callId, address account) public {
        AccountCapitalCall storage acc = accountCapitalCalls[account][callId];
        require(acc.accountType == AccountType.GP || acc.accountType == AccountType.LP, "Invalid account type.");

        acc.hasFailed = true;
        acc.timestamp = block.timestamp;

        emit AccountCapitalCallFailed(callId, account);
    }

    /**
     * @notice Retrieves all fundtoken contracts involved in capital calls.
     * @dev Iterates through the capitalCalls mapping and returns a list of GP and LP fund token contract addresses.
     * @return contracts A list of ISecurityToken addresses of fund token contracts.
     */
    function getFundContracts() public view returns (ISecurityToken[] memory contracts) {
        contracts = new ISecurityToken[](capitalCallsCount * 2); // each capital call involves two fund tokens (GP and LP)
        for (uint256 i = 0; i < capitalCallsCount; i++) {
            contracts[i * 2] = capitalCalls[i].gpFundToken;
            contracts[i * 2 + 1] = capitalCalls[i].lpFundToken;
        }
    }

    /**
     * @notice Adds an account capital call.
     * @dev Creates a new AccountCapitalCall struct and adds it to the accountCapitalCalls mapping.
     * @param callId The ID of the capital call.
     * @param account The address of the account involved in the capital call.
     * @param amount The amount of the capital call for the account.
     * @param accountType The type of the account (GP or LP).
     */
    function addAccountCapitalCall(uint256 callId, address account, uint256 amount, AccountType accountType) public {
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
