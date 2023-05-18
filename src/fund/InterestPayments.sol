// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

// @todo use trusted library for date/time calculations
import "lib/BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract InterestPayments {
    struct InterestEntry {
        uint256 time;
        uint256 capital;
        uint256 daily;
        uint256 total;
    }

    uint256 private constant ANNUAL_COMPOUNDING = 1;
    uint256 private constant QUARTERLY_COMPOUNDING = 2;

    InterestEntry[] private interestEntries;

    /// @notice Add an inflow of funds and update the compounding interest calculations.
    /// @param amount The amount of the inflow.
    /// @param scale The scale factor used to calculate the daily interest rate.
    /// @param interestRate The annual nominal interest rate, in basis points.
    /// @param time The UNIX timestamp at which the inflow occurs.
    /// @param cp The compounding period, either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING.
    /// @return The updated total capital after the inflow.
    function addInflow(uint256 amount, uint256 scale, uint256 interestRate, uint256 time, uint8 cp)
        public
        returns (uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = computeCompounding(cp, scale, interestRate, time);

        if (dt > 0) {
            uint256 od = convertEncodedTime(dt);
            uint256 nd = convertEncodedTime(time);
            uint256 delta = nd - od;
            uint256 comp = d * delta;
            tcf += comp;
        }

        tcf += amount;
        d = ((tcf * interestRate) / scale) / 1000;

        interestEntries.push(InterestEntry(time, capital + amount, d, tcf));

        return tcf;
    }

    /// @notice Add an outflow of funds and update the compounding interest calculations.
    /// @param amount The amount of the outflow.
    /// @param scale The scale factor used to calculate the daily interest rate.
    /// @param interestRate The annual nominal interest rate, in basis points.
    /// @param time The UNIX timestamp at which the outflow occurs.
    /// @param cp The compounding period, either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING.
    /// @return A tuple containing the remaining amount to be withdrawn, the capital paid, and the interest paid.
    function addOutflow(uint256 amount, uint256 scale, uint256 interestRate, uint256 time, uint8 cp)
        public
        returns (uint256, uint256, uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = computeCompounding(cp, scale, interestRate, time);

        uint256 capitalPaid = 0;
        uint256 interestPaid = 0;
        uint256 remainingAmount = amount;

        if (dt > 0 && tcf > 0) {
            uint256 delta = convertEncodedTime(time) - convertEncodedTime(dt);
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
            interestEntries.push(InterestEntry(time, capital, d, tcf));
        }

        return (remainingAmount, capitalPaid, interestPaid);
    }

    /// @notice Compute the compounding interest for the given compounding period.
    /// @param cp The compounding period, either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING.
    /// @param scale The scale factor used to calculate the daily interest rate.
    /// @param interestRate The annual nominal interest rate, in basis points.
    /// @param time The UNIX timestamp at which the computation is performed.
    /// @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
    function computeCompounding(uint8 cp, uint256 scale, uint256 interestRate, uint256 time)
        internal
        returns (uint256, uint256, uint256, uint256)
    {
        if (cp == ANNUAL_COMPOUNDING) {
            return compoundAnnual(scale, interestRate, time);
        } else if (cp == QUARTERLY_COMPOUNDING) {
            return compoundQuarterly(scale, interestRate, time);
        } else {
            revert("Invalid compounding");
        }
    }

    /// @notice Get the UNIX timestamp of the quarter in which the input timestamp occurs.
    /// @param _timestamp The UNIX timestamp for which the quarter is being calculated.
    /// @return The UNIX timestamp of the quarter.
    function getQuarter(uint256 _timestamp) private pure returns (uint256) {
        uint256 year = BokkyPooBahsDateTimeLibrary.getYear(_timestamp);
        uint256 q1 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 1, 1);
        uint256 q2 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 4, 1);
        uint256 q3 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 7, 1);
        uint256 q4 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 10, 1);

        if (_timestamp < q2) {
            return q1;
        } else if (_timestamp < q3) {
            return q2;
        } else if (_timestamp < q4) {
            return q3;
        }
        return q4;
    }

    /// @notice Get the UNIX timestamp of the next quarter after the input timestamp.
    /// @param _timestamp The UNIX timestamp for which the next quarter is being calculated.
    /// @return The UNIX timestamp of the next quarter.
    function nextQuarter(uint256 _timestamp) private pure returns (uint256) {
        uint256 year = BokkyPooBahsDateTimeLibrary.getYear(_timestamp);
        uint256 month = BokkyPooBahsDateTimeLibrary.getMonth(_timestamp);

        if (month == 1) {
            return BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 4, 1);
        } else if (month == 4) {
            return BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 7, 1);
        } else if (month == 7) {
            return BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 10, 1);
        } else if (month == 10) {
            return BokkyPooBahsDateTimeLibrary.timestampFromDate(year + 1, 1, 1);
        } else {
            revert("Invalid time");
        }
    }

    /// @notice Convert an encoded time (UNIX timestamp) into the number of days since the UNIX epoch.
    /// @param timestamp The UNIX timestamp to be converted.
    /// @return The number of days since the UNIX epoch.
    function convertEncodedTime(uint256 timestamp) public pure returns (uint256) {
        return timestamp / (24 * 60 * 60);
    }

    /// @notice Compound interest annually.
    /// @param scale The scale factor used to calculate the daily interest rate.
    /// @param interestRate The annual nominal interest rate, in basis points.
    /// @param time The UNIX timestamp at which the compounding is performed.
    /// @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
    function compoundAnnual(uint256 scale, uint256 interestRate, uint256 time)
        public
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = getLastInterestEntry();
        if (dt > 0) {
            uint256 od = convertEncodedTime(dt);
            uint256 nd = convertEncodedTime(time);

            if (nd > od) {
                uint256 delta = nd - od;
                uint256 ai = d * delta;
                tcf = tcf + ai;
                d = ((tcf * interestRate) / scale) / 1000;
                dt = time;
                interestEntries.push(InterestEntry(dt, capital, d, tcf));
            }
        }
        return (dt, capital, d, tcf);
    }

    /// @notice Compound interest quarterly.
    /// @param scale The scale factor used to calculate the daily interest rate.
    /// @param interestRate The annual nominal interest rate, in basis points.
    /// @param time The UNIX timestamp at which the compounding is performed.
    /// @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
    function compoundQuarterly(uint256 scale, uint256 interestRate, uint256 time)
        public
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 dt, uint256 capital, uint256 d, uint256 tcf) = getLastInterestEntry();
        if (dt > 0) {
            uint256 od = convertEncodedTime(dt);
            uint256 nd = convertEncodedTime(time);

            while (od < nd) {
                od = getNextQuarter(od);
                if (od <= nd) {
                    uint256 delta = od - convertEncodedTime(dt);
                    uint256 ai = d * delta;
                    tcf = tcf + ai;
                    d = ((tcf * interestRate) / scale) / 1000;
                    dt = convertEncodedTime(od) * (24 * 60 * 60); // Convert back to UNIX timestamp
                    interestEntries.push(InterestEntry(dt, capital, d, tcf));
                }
            }
        }
        return (dt, capital, d, tcf);
    }

    /**
     * @dev Returns the most recent interest entry.
     *
     * If there are no entries, it will return a tuple of four zeroes.
     *
     * @return time The timestamp at which the interest entry was made
     * @return capital The principal amount for the interest calculation
     * @return daily The daily interest applied to the capital
     * @return total The total accumulated interest until the entry
     */
    function getLastInterestEntry() public view returns (uint256, uint256, uint256, uint256) {
        if (interestEntries.length == 0) {
            return (0, 0, 0, 0);
        } else {
            InterestEntry storage entry = interestEntries[interestEntries.length - 1];
            return (entry.time, entry.capital, entry.daily, entry.total);
        }
    }

    /// @notice Calculate the day of the next quarter in days since the UNIX epoch,
    ///         given the current day in days since the UNIX epoch.
    /// @param currentDay The current day in days since the UNIX epoch.
    /// @return The day of the next quarter in days since the UNIX epoch.
    function getNextQuarter(uint256 currentDay) public pure returns (uint256) {
        uint256 currentYear = currentDay / 365;
        uint256 currentQuarter = (currentDay % 365) / 90;

        uint256 _nextQuarter = currentQuarter + 1;
        if (_nextQuarter > 3) {
            _nextQuarter = 0;
            currentYear += 1;
        }

        uint256 nextQuarterDay = currentYear * 365 + _nextQuarter * 90;
        return nextQuarterDay;
    }
}
