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
    uint16 public distributionsCount;

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
    function _addDistribution(uint256 amount, string memory distributionType, uint32 time) internal returns (uint16) {
        distributions[distributionsCount] =
            Distribution({amount: amount, distributionType: distributionType, time: time});

        distributionsCount++;
        return distributionsCount - 1;
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
    function _processDistribution(
        IFundToken token,
        string calldata distributionType,
        uint32 time,
        uint16 distId,
        uint256 amount,
        uint256 scale
    ) internal {
        IFundToken(token).distribute(distId, distributionType, time, amount, scale);
    }
}
