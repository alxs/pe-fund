// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Expenses Smart Contract in Solidity
 */
contract Expenses {
    struct Expense {
        uint256 amount;
        uint256 timestamp;
        string expenseType;
    }

    uint256 public totalExpenses;
    Expense[] public expenses;

    /**
     * @notice Returns the total expenses
     * @return Total expenses
     */
    function getTotalExpenses() public view returns (uint256) {
        return totalExpenses;
    }

    /**
     * @notice Sets the total expenses
     * @param value The value to set total expenses to
     */
    function setTotalExpenses(uint256 value) public {
        totalExpenses = value;
    }

    /**
     * @notice Adds an expense
     * @param amount The amount of the expense
     * @param timestamp The timestamp of the expense
     * @param expenseType The type of the expense
     */
    function chargeExpense(uint256 amount, uint256 timestamp, string memory expenseType) public {
        Expense memory newExpense = Expense({amount: amount, timestamp: timestamp, expenseType: expenseType});

        expenses.push(newExpense);

        // Update the total
        totalExpenses += amount;
    }

    /**
     * @notice Get the number of expenses
     * @return Number of expenses
     */
    function getExpensesCount() public view returns (uint256) {
        return expenses.length;
    }
}
