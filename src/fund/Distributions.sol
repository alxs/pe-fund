// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "../interfaces/ISecurityToken.sol";

/**
 * @title Distribution contract
 * @notice This contract implements a distribution system for a given amount, type and timestamp.
 * @dev Storage for distributions and total distribution amount. The contract interfaces with ISecurityToken for token distributions.
 */
contract Distributions {
    // Total amount for distributions
    uint256 public totalDistribution;

    // Mappings of distributions, accessible by their IDs
    mapping(uint32 => Distribution) public distributions;

    // Count of total distributions made
    uint32 public distributionsCount;

    // Struct representing a distribution, including amount, type, and time
    struct Distribution {
        uint256 amount;
        string distributionType;
        uint64 time;
    }

    /**
     * @notice Add a new distribution to the system
     * @dev Updates the distributions mapping with a new distribution struct and increments the distributionsCount
     * @param amount The amount of distribution to be added
     * @param distributionType The type of the distribution
     * @param time The timestamp of the distribution
     * @return The ID of the newly created distribution
     */
    function addDistribution(uint256 amount, string memory distributionType, uint64 time) public returns (uint32) {
        distributions[distributionsCount] =
            Distribution({amount: amount, distributionType: distributionType, time: time});

        distributionsCount++;
        return distributionsCount - 1;
    }

    /**
     * @notice Sets the total distribution
     * @dev Mutates the totalDistribution state variable with the provided value
     * @param value The new total distribution value
     */
    function setTotalDistribution(uint256 value) public {
        totalDistribution = value;
    }

    /**
     * @notice Processes a distribution by interfacing with a token contract
     * @dev Calls the distribute function of a given ISecurityToken contract
     * @param token The address of the target ISecurityToken contract
     * @param distributionType The type of the distribution
     * @param time The time of the distribution
     * @param distId The ID of the distribution
     * @param amount The amount to distribute
     * @param scale The scale of the distribution
     */
    function processDistribution(
        ISecurityToken token,
        string calldata distributionType,
        uint64 time,
        uint32 distId,
        uint256 amount,
        uint256 scale
    ) internal {
        ISecurityToken(token).distribute(distId, distributionType, time, amount, scale);
    }
}
