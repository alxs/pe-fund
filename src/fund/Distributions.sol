// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "../interfaces/IFundToken.sol";

/**
 * @title Distribution Contract
 * @notice Manages the distribution of a specific amount and type at a certain time.
 * @dev This contract holds the total distribution amount and individual distributions. It utilizes the IFundToken interface for token-based distributions.
 */
contract Distributions {
    // Aggregate amount distributed
    uint256 public totalDistribution;

    // Map of distributions, each identifiable by a unique ID
    mapping(uint32 => Distribution) public distributions;

    // Tally of distributions made
    uint32 public distributionsCount;

    // Struct encapsulating properties of a distribution
    struct Distribution {
        uint256 amount;
        string distributionType;
        uint256 time;
    }

    /**
     * @notice Registers a new distribution
     * @dev Appends a new Distribution struct to the distributions mapping and increments the distributionsCount
     * @param amount The volume of distribution
     * @param distributionType The category of the distribution
     * @param time The timestamp associated with the distribution
     * @return The ID assigned to the new distribution
     */
    function addDistribution(uint256 amount, string memory distributionType, uint256 time) public returns (uint32) {
        distributions[distributionsCount] =
            Distribution({amount: amount, distributionType: distributionType, time: time});

        distributionsCount++;
        return distributionsCount - 1;
    }

    /**
     * @notice Defines the total distribution value
     * @dev Replaces the current totalDistribution value with the input parameter
     * @param value The proposed total distribution volume
     */
    function setTotalDistribution(uint256 value) public {
        totalDistribution = value;
    }

    /**
     * @notice Executes a distribution via an IFundToken contract
     * @dev Invokes the distribute function of a specified IFundToken contract
     * @param token The address of the IFundToken contract to be interfaced with
     * @param distributionType The category of the distribution
     * @param time The timestamp associated with the distribution
     * @param distId The ID assigned to the distribution
     * @param amount The volume to be distributed
     * @param scale The proportion of the distribution
     */
    function processDistribution(
        IFundToken token,
        string calldata distributionType,
        uint256 time,
        uint32 distId,
        uint256 amount,
        uint256 scale
    ) internal {
        IFundToken(token).distribute(distId, distributionType, time, amount, scale);
    }
}
