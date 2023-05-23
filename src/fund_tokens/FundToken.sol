// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/IFundToken.sol";
import "./DistributionStorage.sol";
import "./FeeStorage.sol";

/**
 * @title FundToken
 *
 * @notice A token contract for managing security with dividends and fees.
 *
 * The contract inherits from several libraries from OpenZeppelin,
 * as well as from two local contracts: DistributionStorage and FeeStorage.
 *
 * The contract itself implements a security token that has the capability to pause,
 * manage roles, mint, burn, and distribute tokens. It can also charge management fees.
 */
contract FundToken is IFundToken, ERC20Pausable, AccessControl, ReentrancyGuard, DistributionStorage, FeeStorage {
    IComplianceRegistry public complianceRegistry;
    IERC20 public usdc;

    // Constants representing the different roles within the system
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");
    bytes32 public constant TOKEN_ADMIN = keccak256("TOKEN_ADMIN");
    // @todo ^ this is just the fund. do we need more roles?

    // Mappings for storing account related data
    mapping(address => mapping(uint16 => uint256)) private snapshotBalances;
    mapping(address => uint16) private lastFeeIndex;
    mapping(address => uint16) private lastDistributionIndex;
    mapping(address => mapping(uint16 => bool)) public confirmedDistributions;
    mapping(address => mapping(uint16 => bool)) public paidFees;

    uint256 public totalDistributionAmount;

    // Boolean indicating whether or not this is a CommitToken
    bool public isCommitToken;

    modifier noPendingFees(address account) {
        require(getPendingFees(account) == 0, "Account has pending fees");
        _;
    }

    modifier noPendingDistribution(address account) {
        require(getTotalClaimableDistributions(account) == 0, "Distribution pending");
        _;
    }

    /**
     * @notice Constructs the FundToken contract.
     *
     * @param complianceRegistry_ The address of the Compliance Registry contract
     * @param fundAdmin_ The address of the Fund Administrator
     * @param isCommitToken_ A boolean indicating whether this is a Commit Token
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     */
    constructor(
        IComplianceRegistry complianceRegistry_,
        address usdc_,
        address fundAdmin_,
        bool isCommitToken_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        complianceRegistry = complianceRegistry_;
        usdc = IERC20(usdc_);
        isCommitToken = isCommitToken_;

        _setupRole(DEFAULT_ADMIN_ROLE, fundAdmin_);
        _setupRole(FUND_ADMIN, fundAdmin_);
        _setupRole(TOKEN_ADMIN, msg.sender); // Fund contract
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Function to get the total amount of fees due for an account.
     * @param account The account to calculate fees for.
     * @return The total amount of fees due.
     */
    function getPendingFees(address account) public view returns (uint256) {
        uint256 totalAccountFees = 0;
        for (uint16 i = lastFeeIndex[account]; i < totalFees; i++) {
            totalAccountFees += _calculateFee(account, i);
        }
        return totalAccountFees;
    }

    /**
     * @dev Function to get the total claimable distributions for an account.
     * @param account The account to calculate the claimable distributions for.
     * @return The total amount of claimable distributions.
     */
    function getTotalClaimableDistributions(address account) public view returns (uint256) {
        uint256 totalAmount = 0;
        for (uint16 i = lastDistributionIndex[account]; i <= totalDistributions; i++) {
            if (confirmedDistributions[account][i]) {
                totalAmount += _getPendingDistribution(account, i);
            }
        }
        return totalAmount;
    }

    /* ========== MUTATIVE ========== */

    /**
     * @dev Allows a user to pay their fees.
     */
    function payFees() external {
        address account = msg.sender;
        uint256 accountFees = getPendingFees(account);

        require(usdc.transferFrom(account, address(this), accountFees), "USDC transfer failed");

        lastFeeIndex[account] = totalFees;
        emit FeePaid(account, accountFees);
    }

    /**
     * @notice Allows a user to claim all their distributions.
     */
    function claimAllDistributions() external {
        address account = msg.sender;
        uint256 totalAmount = getTotalClaimableDistributions(account);

        require(usdc.transfer(account, totalAmount), "USDC transfer failed");

        lastDistributionIndex[account] = totalDistributions;
        emit DistributionClaimed(account, totalAmount);
    }

    /* ========== RESTRICTED ========== */

    /**
     * @notice Mints new tokens and adds them to the recipient's balance.
     *
     * @dev Only an account with the TOKEN_ADMIN role can call this function.
     * The recipient must be compliant according to the Compliance Registry.
     *
     * @param recipient The address that will receive the minted tokens
     * @param amount The number of tokens to mint
     */
    function mint(address recipient, uint256 amount) public onlyRole(TOKEN_ADMIN) {
        require(complianceRegistry.isCompliant(recipient), "Recipient is not compliant");

        _mint(recipient, amount);
    }

    /**
     * @notice Burns tokens from a specific account.
     *
     * @dev Only an account with the TOKEN_ADMIN role can call this function.
     *
     * @param account The address of the account whose tokens will be burned
     * @param amount The amount of tokens to burn
     */

    function burnFrom(address account, uint256 amount)
        public
        noPendingFees(account)
        noPendingDistribution(account)
        onlyRole(TOKEN_ADMIN)
    {
        _burn(account, amount);
    }

    /**
     * @notice Charges management fee from all token holders.
     *
     * @dev Only an account with the FUND_ADMIN role can call this function.
     *
     * @param mgtFee The management fee to be charged
     * @param price The price per token
     * @param timestamp The timestamp at which the fee was charged
     */
    function chargeManagementFee(uint8 mgtFee, uint16 id, uint256 price, uint32 timestamp)
        public
        onlyRole(FUND_ADMIN)
    {
        _addFee(mgtFee, id, price, timestamp);
    }

    /**
     * @notice Updates the fee status for a list of accounts.
     *
     * @dev Only an account with the FUND_ADMIN role can call this function.
     *
     * @param feeId The ID of the fee to update
     * @param accounts The accounts for which the fee status will be updated
     */
    function markFeeAsPaid(uint16 feeId, address[] memory accounts) public onlyRole(FUND_ADMIN) {
        // Maybe emit event here instead of ts
        for (uint256 i = 0; i < accounts.length; i++) {
            paidFees[accounts[i]][feeId] = true;
        }
    }

    /**
     * @notice Distributes tokens among all token holders.
     *
     * @dev Only an account with the TOKEN_ADMIN role can call this function.
     * This operation is not supported for commit tokens.
     *
     * @param distId The ID of the distribution
     * @param distType The type of distribution
     * @param time The timestamp at which the distribution occurs
     * @param amount The total amount of tokens to distribute
     * @param scale The scale factor for the distribution
     */
    function distribute(uint16 distId, string calldata distType, uint32 time, uint256 amount, uint256 scale)
        external
        onlyRole(TOKEN_ADMIN)
    {
        require(!isCommitToken, "This operation is not supported for commit tokens");

        require(totalSupply() > 0, "No holders to distribute to");

        uint256 scaledAmount = amount * scale;
        uint256 scaledShare = scaledAmount / totalSupply();
        require(scaledShare > 0, "Invalid distribution");

        _addDistribution(distId, scaledShare, scale, distType, time);
        totalDistributionAmount += amount;
    }

    /**
     * @dev Function to confirm a pending distribution for an account.
     * @param account The account confirming the distribution.
     * @param distId The ID of the distribution to confirm.
     */
    function confirmDistribution(address account, uint16 distId) external onlyRole(TOKEN_ADMIN) {
        require(_getPendingDistribution(account, distId) > 0, "No pending distributions for this account and ID");
        confirmedDistributions[account][distId] = true;
        emit DistributionConfirmed(account, distId);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `TOKEN_ADMIN` role.
     */
    function pause() public onlyRole(TOKEN_ADMIN) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `TOKEN_ADMIN` role.
     */
    function unpause() public onlyRole(TOKEN_ADMIN) {
        _unpause();
    }

    /* ========== INTERNAL ========== */

    /**
     * @dev Calculate fee amount for a specific feeId for an account.
     * @param account Account to calculate the fee for.
     * @param feeId ID of the fee to calculate.
     */
    function _calculateFee(address account, uint16 feeId) private view returns (uint256) {
        Fee memory fee = _getFee(feeId);
        uint256 snapshotBalance = snapshotBalances[account][feeId];
        uint256 charge = ((snapshotBalance * fee.fee) / 1000) * fee.price;
        return charge;
    }

    /**
     * @dev Function to get the pending distribution amount for an account and distribution ID.
     * @param account The account to calculate the distribution for.
     * @param distId The ID of the distribution to calculate.
     * @return The pending distribution amount.
     */
    function _getPendingDistribution(address account, uint16 distId) private view returns (uint256) {
        uint256 snapshotBalance = snapshotBalances[account][distId];
        Distribution memory dist = _getDistribution(distId);
        uint256 userShare = dist.scaledShare * snapshotBalance / dist.scale;

        return userShare;
    }

    /**
     * @dev Overriding ERC20Pausable's _beforeTokenTransfer function.
     * Updates snapshot balances and ensures the operation is compliant.
     * This function is called prior to any transfer of tokens.
     *
     * @param from The sender's address
     * @param to The receiver's address
     * @param amount The amount of tokens being transferred
     *
     * Requirements:
     * - Sender and recipient must be compliant or an address zero.
     * - Commit token operations can only be performed by an account with the TOKEN_ADMIN role.
     * - Neither the sender nor recipient have pending fees or distributions.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
        noPendingFees(from)
        noPendingDistribution(from)
        nonReentrant
    {
        require(!isCommitToken || hasRole(TOKEN_ADMIN, msg.sender), "Operation not supported for commit tokens");

        // Ensure sender and recipient are compliant
        require(complianceRegistry.isCompliant(from) || from == address(0), "Sender non-compliant");
        require(complianceRegistry.isCompliant(to) || to == address(0), "Recipient non-compliant");

        // Update the balance snapshots for sender and receiver
        _updateSnapshot(from);
        _updateSnapshot(to);

        // Call the inherited _beforeTokenTransfer function
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Updates the balance snapshot for an account.
     * If the snapshot index for distributions or fees is outdated, it creates a new snapshot.
     * A snapshot captures the account balance at a specific point in time (either a distribution or fee event).
     * This snapshot is used to determine the account's eligibility for fee claims or distributions.
     *
     * @param account The account for which the snapshot is being updated
     */
    function _updateSnapshot(address account) private {
        uint16 currentSnapshotIndex = totalDistributions;
        uint16 lastSnapshotIndex = lastDistributionIndex[account];

        // If the distribution snapshot index is outdated, update it
        if (currentSnapshotIndex != lastSnapshotIndex) {
            snapshotBalances[account][currentSnapshotIndex] = balanceOf(account);
            lastDistributionIndex[account] = currentSnapshotIndex;
        }

        uint16 currentFeeSnapshotIndex = totalFees;
        uint16 lastFeeSnapshotIndex = lastFeeIndex[account];

        // If the fee snapshot index is outdated, update it
        if (currentFeeSnapshotIndex != lastFeeSnapshotIndex) {
            snapshotBalances[account][currentFeeSnapshotIndex] = balanceOf(account);
            lastFeeIndex[account] = currentFeeSnapshotIndex;
        }
    }

    event FeePaid(address indexed payer, uint256 amount);
    event DistributionConfirmed(address indexed receiver, uint32 distributionId);
    event DistributionClaimed(address indexed receiver, uint256 totalAmount);
}
