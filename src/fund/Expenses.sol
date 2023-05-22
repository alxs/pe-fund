// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Expenses Contract
 * @notice This contract keeps track of various expenses and their metadata.
 */
contract Expenses {
    struct Expense {
        uint256 amount; // The expense amount
        uint256 timestamp; // The time when the expense occurred
        string expenseType; // The type of expense
    }

    uint256 public totalExpenses; // Total amount of all expenses
    Expense[] public expenses; // An array to store the Expense structs

    /**
     * @notice Returns the total sum of all expenses.
     * @return A uint256 representing the total amount of expenses.
     */
    function getTotalExpenses() public view returns (uint256) {
        return totalExpenses;
    }

    /**
     * @notice Allows to manually set the total amount of expenses.
     * @param value The value to set the total expenses to.
     */
    function setTotalExpenses(uint256 value) public {
        totalExpenses = value;
    }

    /**
     * @notice Adds a new expense to the expenses array and updates the totalExpenses.
     * @param amount The amount of the expense.
     * @param timestamp The time when the expense occurred.
     * @param expenseType A string denoting the type of the expense.
     */
    function chargeExpense(uint256 amount, uint256 timestamp, string memory expenseType) public {
        Expense memory newExpense = Expense({amount: amount, timestamp: timestamp, expenseType: expenseType});

        expenses.push(newExpense);
        totalExpenses += amount;
    }

    /**
     * @notice Retrieves the current number of expenses stored in the contract.
     * @return A uint256 representing the number of expenses.
     */
    function getExpensesCount() public view returns (uint256) {
        return expenses.length;
    }
}
