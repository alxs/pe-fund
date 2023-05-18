// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

/**
 * @title Distributions Contract
 * @dev Contract to handle distributions
 */
contract DistributionManager {
    struct DistributionEntry {
        uint256 amount;
        string distributionType;
        uint64 time;
    }

    struct AccountDistributionEntry {
        uint256 amount;
        uint64 time;
        uint32 status;
    }

    uint32 public totalDistributions;
    uint256 public totalDistributionAmount;
    mapping(uint32 => DistributionEntry) private distributions;
    mapping(uint32 => mapping(address => AccountDistributionEntry)) private accountDistributions;

    uint32 private constant DISTRIBUTION_PENDING = 1;
    uint32 private constant DISTRIBUTION_CONFIRMED = 2;

    /**
     * @dev Throws if account has pending distributions.
     */
    modifier noPendingDistribution(address account) {
        for (uint32 i = 0; i < totalDistributions; i++) {
            AccountDistributionEntry storage entry = accountDistributions[i][account];
            require(entry.status != DISTRIBUTION_PENDING, "Distribution Pending");
        }
        _;
    }

    constructor() {}

    /* ========== MUTATIVE ========== */

    // @todo allow users to claim distribution
    // for (uint32 i = lastDistributionIndex[account]; i < distributionCount; i++) {
    //     Distribution memory dist = distributions[i];
    //     uint256 snapshotBalance = snapshotBalances[account][i];
    //     uint256 share = dist.amount * snapshotBalance / dist.scale;
    //     balance += share;
    // }

    /* ========== INTERNAL ========== */

    /**
     * @dev Add a new distribution
     * @param amount Amount of distribution
     * @param distributionType Type of distribution
     * @param time Timestamp
     */
    function _addDistribution(uint32 _ditId, uint256 amount, string memory distributionType, uint64 time) internal {
        distributions[_ditId] = DistributionEntry(amount, distributionType, time);
        totalDistributionAmount += amount;
        totalDistributions += 1;
    }

    /**
     * @dev Add an account distribution
     * @param distId Distribution id
     * @param account Account address
     * @param amount Amount of distribution
     */
    function _addAccountDistribution(uint32 distId, address account, uint256 amount) internal {
        accountDistributions[distId][account] = AccountDistributionEntry(amount, 0, DISTRIBUTION_PENDING);
    }

    /**
     * @dev Confirm a distribution
     * @param distId Distribution id
     * @param account Account address
     * @param ts Timestamp
     */
    function _confirmDistribution(uint32 distId, address account, uint64 ts) internal {
        AccountDistributionEntry storage entry = accountDistributions[distId][account];
        entry.time = ts;
        entry.status = DISTRIBUTION_CONFIRMED;
    }
}
