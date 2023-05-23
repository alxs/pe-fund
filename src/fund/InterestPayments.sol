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
        uint32 time; // UNIX timestamp of the entry
        uint256 capital; // Principal amount
        uint256 daily; // Daily interest
        uint256 total; // Total accumulated interest
    }

    enum CompoundingPeriod {
        ANNUAL_COMPOUNDING,
        QUARTERLY_COMPOUNDING
    }

    InterestEntry[] private interestEntries;
    CompoundingPeriod public compoundingInterval;

    constructor(CompoundingPeriod _compoundingInterval) {
        compoundingInterval = _compoundingInterval;
    }

    /**
     * @dev Adds an inflow of funds and updates the compounding interest calculations.
     * @param amount Amount of the inflow
     * @param scale Scale factor for calculating the daily interest rate
     * @param interestRate Annual nominal interest rate in basis points
     * @param time UNIX timestamp of the inflow occurrence
     * @param cp Compounding period - either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING
     * @return The updated total capital after the inflow
     */
    function _addInflow(uint256 amount, uint256 scale, uint256 interestRate, uint32 time, CompoundingPeriod cp)
        internal
        returns (uint256)
    {
        (uint32 dt, uint256 capital, uint256 d, uint256 tcf) = _computeCompounding(cp, scale, interestRate, time);

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

    /**
     * @dev Adds an outflow of funds and updates the compounding interest calculations.
     * @param amount Amount of the outflow
     * @param scale Scale factor for calculating the daily interest rate
     * @param interestRate Annual nominal interest rate in basis points
     * @param time UNIX timestamp of the outflow occurrence
     * @param cp Compounding period - either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING
     * @return A tuple containing the remaining amount to be withdrawn, the capital paid, and the interest paid.
     */
    function _addOutflow(uint256 amount, uint256 scale, uint256 interestRate, uint32 time, CompoundingPeriod cp)
        internal
        returns (uint256, uint256, uint256)
    {
        (uint32 dt, uint256 capital, uint256 d, uint256 tcf) = _computeCompounding(cp, scale, interestRate, time);

        uint256 capitalPaid = 0;
        uint256 interestPaid = 0;
        uint256 remainingAmount = amount;

        if (dt > 0 && tcf > 0) {
            uint32 delta = uint32(convertEncodedTime(time) - convertEncodedTime(dt));
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

    /**
     * @notice Calculates the compounding interest for a specified compounding period.
     * @dev Chooses between annual and quarterly compounding based on the `cp` parameter.
     * Reverts if an invalid compounding period is passed.
     * @param cp The compounding period (either ANNUAL_COMPOUNDING or QUARTERLY_COMPOUNDING).
     * @param scale The scale factor to compute the daily interest rate.
     * @param interestRate The yearly nominal interest rate, expressed in basis points.
     * @param time The UNIX timestamp at the time of computation.
     * @return A tuple containing the last interest payment date, the capital, the daily interest, and the total capital.
     */
    function _computeCompounding(CompoundingPeriod cp, uint256 scale, uint256 interestRate, uint32 time)
        internal
        returns (uint32, uint256, uint256, uint256)
    {
        if (cp == CompoundingPeriod.ANNUAL_COMPOUNDING) {
            return _compoundAnnual(scale, interestRate, time);
        } else if (cp == CompoundingPeriod.QUARTERLY_COMPOUNDING) {
            return _compoundQuarterly(scale, interestRate, time);
        } else {
            revert("Invalid compounding period");
        }
    }

    /**
     * @notice Determines the UNIX timestamp of the quarter in which the given timestamp occurs.
     * @param timestamp The UNIX timestamp to compute the quarter for.
     * @return The UNIX timestamp representing the beginning of the quarter.
     */
    function _getQuarter(uint256 timestamp) private pure returns (uint256) {
        uint256 year = BokkyPooBahsDateTimeLibrary.getYear(timestamp);
        uint256 q1 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 1, 1);
        uint256 q2 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 4, 1);
        uint256 q3 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 7, 1);
        uint256 q4 = BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 10, 1);

        if (timestamp < q2) {
            return q1;
        } 
        if (timestamp < q3) {
            return q2;
        } 
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
    function _nextQuarter(uint32 timestamp) public pure returns (uint32) {
        uint16 year = uint16(BokkyPooBahsDateTimeLibrary.getYear(timestamp));
        uint8 month = uint8(BokkyPooBahsDateTimeLibrary.getMonth(timestamp));

        if (month == 1) {
            return uint32(BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 4, 1));
        } else if (month == 4) {
            return uint32(BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 7, 1));
        } else if (month == 7) {
            return uint32(BokkyPooBahsDateTimeLibrary.timestampFromDate(year, 10, 1));
        } else if (month == 10) {
            return uint32(BokkyPooBahsDateTimeLibrary.timestampFromDate(year + 1, 1, 1));
        } else {
            revert("Invalid time");
        }
    }

    /**
     * @notice Convert a UNIX timestamp into the number of days since the UNIX epoch.
     * @param timestamp The UNIX timestamp to be converted.
     * @return The number of days since the UNIX epoch.
     */
    function convertEncodedTime(uint32 timestamp) public pure returns (uint256) {
        return timestamp / (24 * 60 * 60);
    }

    /**
     * @notice Compound interest annually.
     * @param scale The scale factor used to calculate the daily interest rate.
     * @param interestRate The annual nominal interest rate, in basis points.
     * @param time The UNIX timestamp at which the compounding is performed.
     * @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
     */
    function _compoundAnnual(uint256 scale, uint256 interestRate, uint32 time)
        internal
        returns (uint32, uint256, uint256, uint256)
    {
        (uint32 dt, uint256 capital, uint256 d, uint256 tcf) = getLastInterestEntry();
        if (dt > 0) {
            uint16 od = uint16(convertEncodedTime(dt));
            uint16 nd = uint16(convertEncodedTime(time));

            if (nd > od) {
                uint16 delta = nd - od;
                uint256 ai = d * delta;
                tcf = tcf + ai;
                d = ((tcf * interestRate) / scale) / 1000;
                dt = time;
                interestEntries.push(InterestEntry(dt, capital, d, tcf));
            }
        }
        return (dt, capital, d, tcf);
    }

    /**
     * @notice Compound interest quarterly.
     * @param scale The scale factor used to calculate the daily interest rate.
     * @param interestRate The annual nominal interest rate, in basis points.
     * @param time The UNIX timestamp at which the compounding is performed.
     * @return A tuple containing the date of the last interest payment, the capital, the daily interest, and the total capital.
     */
    function _compoundQuarterly(uint256 scale, uint256 interestRate, uint32 time)
        internal
        returns (uint32, uint256, uint256, uint256)
    {
        (uint32 dt, uint256 capital, uint256 d, uint256 tcf) = getLastInterestEntry();
        if (dt > 0) {
            uint32 od = uint32(convertEncodedTime(dt));
            uint32 nd = uint32(convertEncodedTime(time));

            while (od < nd) {
                od = _nextQuarter(od);
                if (od <= nd) {
                    uint256 delta = od - convertEncodedTime(dt);
                    uint256 ai = d * delta;
                    tcf = tcf + ai;
                    d = ((tcf * interestRate) / scale) / 1000;
                    dt = uint32(convertEncodedTime(od) * (24 * 60 * 60)); // Convert back to UNIX timestamp
                    interestEntries.push(InterestEntry(dt, capital, d, tcf));
                }
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
    function getLastInterestEntry() public view returns (uint32, uint256, uint256, uint256) {
        if (interestEntries.length == 0) {
            return (0, 0, 0, 0);
        } else {
            InterestEntry storage entry = interestEntries[interestEntries.length - 1];
            return (entry.time, entry.capital, entry.daily, entry.total);
        }
    }
}
