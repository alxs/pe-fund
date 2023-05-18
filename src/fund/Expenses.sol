// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Expenses Smart Contract in Solidity
 */
contract Expenses {

    struct Expense {
        uint256 amount;
        uint64 timestamp;
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
     * @param _value The value to set total expenses to
     */
    function setTotalExpenses(uint256 _value) public {
        totalExpenses = _value;
    }

    /**
     * @notice Adds an expense
     * @param _amount The amount of the expense
     * @param _time The timestamp of the expense
     * @param _expenseType The type of the expense
     */
    function chargeExpense(uint256 _amount, uint64 _time, string memory _expenseType) public {
        Expense memory newExpense = Expense({
            amount: _amount,
            timestamp: _time,
            expenseType: _expenseType
        });
        
        expenses.push(newExpense);

        // Update the total
        totalExpenses += _amount;
    }

    /**
     * @notice Get the number of expenses
     * @return Number of expenses
     */
    function getExpensesCount() public view returns (uint256) {
        return expenses.length;
    }
}
