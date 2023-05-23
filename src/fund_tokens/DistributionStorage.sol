// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Distributions Contract
 * @dev Contract to handle distributions
 */
contract DistributionStorage {
    // Structure representing a distribution event with amount, scale, totalSupply, type, and the timestamp of creation.
    struct Distribution {
        uint256 scaledShare; // The total amount to be distributed.
        uint256 scale; // The scaling factor used for distribution.
        string distributionType; // The type of the distribution, e.g., "dividend", "airdrop", etc.
        uint32 timestamp; // Timestamp when the distribution event was created.
    }

    mapping(uint16 => Distribution) private distributions;
    uint16 internal totalDistributions;

    /**
     * @dev Add a new distribution
     * @param distId Identifier for the distribution
     * @param scaledShare Amount of distribution scaled by a factor
     * @param scale Scaling factor for the distribution
     * @param distributionType Type of distribution
     * @param time Timestamp
     */
    function _addDistribution(
        uint16 distId,
        uint256 scaledShare,
        uint256 scale,
        string memory distributionType,
        uint32 time
    ) internal {
        require(distributions[distId].timestamp == 0, "Distribution already set");

        distributions[distId] = Distribution(scaledShare, scale, distributionType, time);
        ++totalDistributions;
    }

    /**
     * @dev Gets the distribution using its id.
     * @param distId Identifier for the distribution.
     * @return scaledShare, scale, distributionType, time Returns the scaled share, scale factor, distribution type, and timestamp for the specified distribution id.
     */
    function _getDistribution(uint16 distId) internal view returns (Distribution storage) {
        return distributions[distId];
    }
}
