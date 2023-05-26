// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

// This library is actually maintained, gas efficient and well designed.
import "lib/BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

/**
 * @title InterestPayments
 * @dev A smart contract for managing interest payments
 */
contract InterestPayments {
    struct InterestEntry {
        uint256 timestamp; // UNIX timestamp of the entry
        uint256 capital; // Compounded capital amount.
        uint256 daily; // Daily interest rate.
        uint256 totalCashFlow; // Total cashflow including the interest.
    }

    enum CompoundingPeriod {
        ANNUAL_COMPOUNDING,
        QUARTERLY_COMPOUNDING
    }

    InterestEntry[] public interestEntries;

    // Event declarations.
    event InterestEntryAdded(uint256 timestamp, uint256 capital, uint256 dailyInterestRate, uint256 totalCashFlow);

    /* ========== INTERNAL ========== */

    /**
     * @dev Adds an inflow of funds and updates the compounding interest calculations.
     * @param amount Amount of the inflow
     * @param scale Scale factor for calculating the daily interest rate
     * @param interestRate Annual nominal interest rate in basis points
     * @param time UNIX timestamp of the inflow occurrence
     * @param cp Compounding period - either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING
     * @return The updated total capital after the inflow
     */
    function _addInflow(uint256 amount, uint8 scale, uint256 interestRate, uint256 time, CompoundingPeriod cp)
        internal
        returns (uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = _computeCompounding(cp, scale, interestRate, time);

        if (dt > 0) {
            uint256 od = _getDays(dt);
            uint256 nd = _getDays(time);
            uint256 delta = nd - od;
            uint256 comp = d * delta;
            tcf += comp;
        }

        tcf += amount;
        d = ((tcf * interestRate) / scale) / 1000;

        _addInterestEntry(time, capital + amount, d, tcf);
        return tcf;
    }

    /**
     * @dev Adds an outflow of funds and updates the compounding interest calculations.
     * @param amount Amount of the outflow
     * @param scale Scale factor for calculating the daily interest rate
     * @param interestRate Annual nominal interest rate in basis points
     * @param time UNIX timestamp of the outflow occurrence
     * @param cp Compounding period - either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING
     * @return A tuple containing the remaining amount to be withdrawn, the capital paid, and the interest paid.
     */
    function _addOutflow(uint256 amount, uint8 scale, uint256 interestRate, uint32 time, CompoundingPeriod cp)
        internal
        returns (uint256, uint256, uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = _computeCompounding(cp, scale, interestRate, time);

        uint256 capitalPaid = 0;
        uint256 interestPaid = 0;
        uint256 remainingAmount = amount;

        if (dt > 0 && tcf > 0) {
            uint256 delta = _getDays(time) - _getDays(dt);
            tcf += d * delta;

            if (amount <= capital) {
                tcf -= amount;
                d = ((tcf * interestRate) / scale) / 1000;
                capital -= amount;
                capitalPaid = amount;
                remainingAmount = 0;
            } else if (amount <= tcf) {
                capitalPaid = capital;
                capital = 0;
                interestPaid = amount - capitalPaid;
                tcf -= amount;
                d = ((tcf * interestRate) / scale) / 1000;
                remainingAmount = 0;
            } else {
                capitalPaid = capital;
                interestPaid = tcf - capitalPaid;
                remainingAmount -= tcf;
                tcf = 0;
                d = 0;
            }
            _addInterestEntry(time, capital, d, tcf);
        }

        return (remainingAmount, capitalPaid, interestPaid);
    }

    /* ========== PRIVATE ========== */

    /**
     * @dev Adds a new interest entry to the 'interestEntries' list and triggers the InterestEntryAdded event.
     * @param timestamp The timestamp related to this interest entry.
     * @param capital The compounded capital amount.
     * @param dailyInterestRate The daily interest rate.
     * @param totalCashFlow The total cashflow including the interest.
     */
    function _addInterestEntry(uint256 timestamp, uint256 capital, uint256 dailyInterestRate, uint256 totalCashFlow)
        private
    {
        interestEntries.push(InterestEntry(timestamp, capital, dailyInterestRate, totalCashFlow));
        emit InterestEntryAdded(timestamp, capital, dailyInterestRate, totalCashFlow);
    }

    /**
     * @notice Calculates the compounding interest for a specified compounding period.
     * @dev Chooses between annual and quarterly compounding based on the `cp` parameter.
     * Reverts if an invalid compounding period is passed.
     * @param cp The compounding period (either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING).
     * @param scale The scale factor to compute the daily interest rate.
     * @param interestRate The yearly nominal interest rate, expressed in basis points.
     * @return A tuple containing the last interest payment date, the capital, the daily interest, and the total capital.
     */
    function _computeCompounding(CompoundingPeriod cp, uint8 scale, uint256 interestRate, uint256 timestamp)
        private
        returns (uint256, uint256, uint256, uint256)
    {
        if (cp == CompoundingPeriod.ANNUAL_COMPOUNDING) {
            return _compoundAnnual(scale, interestRate, timestamp);
        } else if (cp == CompoundingPeriod.QUARTERLY_COMPOUNDING) {
            return _compoundQuarterly(scale, interestRate, timestamp);
        } else {
            revert("Invalid compounding period");
        }
    }

    /**
     * @notice Compound interest annually.
     * @param scale The scale factor used to calculate the daily interest rate.
     * @param interestRate The annual nominal interest rate, in basis points.
     * @param timestamp The UNIX timestamp at which the compounding is performed.
     * @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
     */
    function _compoundAnnual(uint256 scale, uint256 interestRate, uint256 timestamp)
        private
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = _getLastInterestEntry();
        if (dt > 0) {
            uint256 nextYear = BokkyPooBahsDateTimeLibrary.getYear(dt) + 1;
            uint256 latestYear = BokkyPooBahsDateTimeLibrary.getYear(timestamp);

            while (nextYear <= latestYear) {
                uint256 nextYearTimestamp = BokkyPooBahsDateTimeLibrary.timestampFromDate(nextYear, 1, 1);
                uint256 delta = BokkyPooBahsDateTimeLibrary.diffDays(dt, nextYearTimestamp);
                uint256 ai = d * delta;
                tcf = tcf + ai;
                d = ((tcf * interestRate) / scale) / 1000;
                _addInterestEntry(dt, capital, d, tcf);

                dt = nextYearTimestamp;
                ++nextYear;
            }
        }
        return (dt, capital, d, tcf);
    }

    /**
     * @notice Compound interest quarterly.
     * @param scale The scale factor used to calculate the daily interest rate.
     * @param interestRate The annual nominal interest rate, in basis points.
     * @param timestamp The UNIX timestamp at which the compounding is performed.
     * @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
     */
    function _compoundQuarterly(uint8 scale, uint256 interestRate, uint256 timestamp)
        private
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = _getLastInterestEntry();
        if (dt > 0) {
            uint256 od = _getDays(dt);
            uint256 oqt = _getDays(_nextQuarter(dt));
            uint256 nqt = _getDays(_getQuarter(timestamp));

            while (od <= nqt) {
                uint256 delta = oqt - od;
                uint256 ai = d * delta;
                tcf = tcf + ai;
                d = ((tcf * interestRate) / scale) / 1000;
                dt = od * 86400; // Convert back to UNIX timestamp
                _addInterestEntry(dt, capital, d, tcf);

                od = _nextQuarter(od);
            }
        }
        return (dt, capital, d, tcf);
    }

    /**
     * @notice Returns the most recent interest entry.
     *         If there are no entries, it will return a tuple of four zeroes.
     * @return time The timestamp at which the interest entry was made
     * @return capital The principal amount for the interest calculation
     * @return daily The daily interest applied to the capital
     * @return total The total accumulated interest until the entry
     */

    function _getLastInterestEntry() private view returns (uint256, uint256, uint256, uint256) {
        if (interestEntries.length == 0) {
            return (0, 0, 0, 0);
        } else {
            InterestEntry memory entry = interestEntries[interestEntries.length - 1];
            return (entry.timestamp, entry.capital, entry.daily, entry.totalCashFlow);
        }
    }

    /**
     * @notice Convert a UNIX timestamp into the number of days since the UNIX epoch.
     * @param timestamp The UNIX timestamp to be converted.
     * @return The number of days since the UNIX epoch.
     */
    function _getDays(uint256 timestamp) private pure returns (uint256) {
        return timestamp / 86400;
    }

    /**
     * @notice Determines the UNIX timestamp of the quarter in which the given timestamp occurs.
     * @param timestamp The UNIX timestamp to compute the quarter for.
     * @return The UNIX timestamp representing the beginning of the quarter.
     */
    function _getQuarter(uint256 timestamp) private pure returns (uint256) {
        uint256 year = BokkyPooBahsDateTimeLibrary.getYear(timestamp);
        // Ugly but gas efficient
        uint256 q2 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 4, 1);
        if (timestamp < q2) {
            return BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 1, 1);
        }
        uint256 q3 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 7, 1);
        if (timestamp < q3) {
            return q2;
        }
        uint256 q4 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 10, 1);
        if (timestamp < q4) {
            return q3;
        }
        return q4;
    }

    /**
     * @notice Determines the UNIX timestamp of the next quarter following the given timestamp.
     * @param timestamp The UNIX timestamp to compute the next quarter for.
     * @return The UNIX timestamp representing the beginning of the next quarter.
     */
    function _nextQuarter(uint256 timestamp) private pure returns (uint256) {
        return _getQuarter(BokkyPooBahsDateTimeLibrary.addMonths(timestamp, 3));
    }
}
