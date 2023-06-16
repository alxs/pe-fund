// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/access/AccessControl.sol";
import "openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/IFundToken.sol";

/**
 * @title FundToken
 * @notice This is an implementation of a token representing a stake in a Private Equity fund with distribution, fee and compliance features.
 * @dev This contract extends ERC20Pausable for pausable token transfers, AccessControl for role-based
 * access control, and ReentrancyGuard to prevent re-entrancy attacks.
 *
 * All token holders are subject to fees and are eligible for distributions. Fees and distributions are calculated based on token
 * balances at the time events occur and are recorded using a snapshot mechanism. This allows for fee and distribution calculations
 * based on historical balances. An account must pay all pending fees and claim all distributions before burning tokens from their balance.
 *
 * Important note: An account must pay all pending fees and claim all distributions before burning tokens from their balance.
 *
 * Commit tokens come with extra restrictions: they can't be transferred freely and don't support distributions.
 *
 * Roles:
 * - TOKEN_ADMIN: This role can mint and burn tokens, pause/unpause token transfers, distribute tokens, confirm distributions,
 *   and charge management fees.
 * - FUND_ADMIN: This role can mark fees as paid.
 *
 * The constructor sets the TOKEN_ADMIN as the contract deployer and the FUND_ADMIN as a separate address.
 */
contract FundToken is IFundToken, ERC20Pausable, AccessControl, ReentrancyGuard {
    // Structs
    struct Fee {
        uint8 fee;
        uint256 price;
    }

    struct Distribution {
        uint256 scaledShare;
        uint16 id;
        uint8 scale;
        string distributionType;
    }

    /* ========== STATE VARIABLES ========== */

    // Role definitions
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");
    bytes32 public constant TOKEN_ADMIN = keccak256("TOKEN_ADMIN");

    // Contract references
    IComplianceRegistry public complianceRegistry;
    IERC20 public usdc;

    // Fee and distribution data
    Distribution[] public distributions;
    Fee[] public fees;
    uint256 public totalDistributionAmount;
    uint256 public feesPaid;

    // Account-level storage for snapshot balances, fee indices, and distribution data
    mapping(address => mapping(uint256 => uint256)) private snapshotBalances;
    mapping(address => uint256) private lastFeeIndex;
    mapping(address => uint256) private lastDistributionIndex;
    mapping(address => mapping(uint256 => bool)) public confirmedDistributions;

    bool public isCommitToken;

    /* ========== EVENTS ========== */

    event FeeRequested(uint256 indexed feeId, uint8 feePm, uint256 price);
    event FeesPaid(address indexed account, uint256 amount);
    event FeesWaived(address indexed account, uint256 upToFeeId);
    event DistributionAdded(uint256 indexed distId, string distType, uint256 amount, uint8 scale);
    event DistributionConfirmed(address indexed recipient, uint256 distributionId);
    event DistributionCancelled(address indexed recipient, uint16 distId);
    event DistributionClaimed(address indexed recipient, uint256 totalAmount);

    /* ========== MODIFIERS ========== */

    modifier noPendingFees(address account) {
        require(getPendingFees(account) == 0, "Account has pending fees");
        _;
    }

    modifier noPendingDistribution(address account) {
        require(getTotalClaimableDistributions(account) == 0, "Distribution pending");
        _;
    }

    /* ========== INITIALISATION ========== */

    /**
     * @notice Constructs the FundToken contract.
     *
     * @param complianceRegistry_ The address of the Compliance Registry contract
     * @param usdc_ The address of the USDC contract
     * @param fundAdmin_ The address of the Fund Administrator
     * @param isCommitToken_ If true, restricts token operations to TOKEN_ADMIN role
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

    /* ========== READ-ONLY FUNCTIONS ========== */

    /**
     * @dev Retrieves the total amount of pending fees for an account.
     *
     * @param account The account to calculate fees for.
     * @return Total amount of fees due.
     */
    function getPendingFees(address account) public view returns (uint256) {
        uint256 totalAccountFees = 0;
        for (uint256 i = lastFeeIndex[account]; i < fees.length; i++) {
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
        for (uint256 i = lastDistributionIndex[account]; i <= distributions.length; i++) {
            if (confirmedDistributions[account][i]) {
                totalAmount += _getPendingDistribution(account, i);
            }
        }
        return totalAmount;
    }

    /* ========== MUTATIVE ========== */

    /**
     * @notice Allows a user to pay their outstanding fees.
     *
     * @dev The function transfers USDC equivalent to the outstanding fees from the user's account to the contract.
     * It updates the `lastFeeIndex` to reflect that all past fees have been paid, and emits a `FeesPaid` event.
     */
    function payFees() external {
        address account = msg.sender;
        uint256 accountFees = getPendingFees(account);

        lastFeeIndex[account] = fees.length - 1;
        feesPaid += accountFees;

        require(usdc.transferFrom(account, address(this), accountFees), "USDC transfer failed");
        emit FeesPaid(account, accountFees);
    }

    /**
     * @notice Allows a user to claim all their confirmed distributions.
     *
     * @dev The function transfers USDC equivalent to the total claimable distributions to the user's account.
     * It updates the `lastDistributionIndex` to reflect that all past distributions have been claimed,
     * and emits a `DistributionClaimed` event.
     */
    function claimAllDistributions() external {
        address account = msg.sender;
        uint256 totalAmount = getTotalClaimableDistributions(account);

        require(usdc.transfer(account, totalAmount), "USDC transfer failed");

        lastDistributionIndex[account] = distributions.length - 1;
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
        _mint(recipient, amount);
    }

    /**
     * @notice Burns tokens from a specific account.
     *
     * @dev Only an account with the TOKEN_ADMIN role can call this function.
     * The account should not have any pending fees or distributions.
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
     * @dev Only an account with the TOKEN_ADMIN role can call this function.
     * The new fee is added to the fees array and an event `FeeRequested` is emitted.
     *
     * @param mgtFee The management fee to be charged (as a percentage multiplied by 10)
     * @param price The price per token
     */
    function chargeManagementFee(uint8 mgtFee, uint256 price) public onlyRole(TOKEN_ADMIN) {
        fees.push(Fee(mgtFee, price));
        emit FeeRequested(fees.length - 1, mgtFee, price);
    }

    /**
     * @notice Updates the fee status for a list of accounts.
     *
     * @dev Only an account with the FUND_ADMIN role can call this function.
     *
     * @param upToId The ID of the last fee ID to be marked as paid.
     * @param accounts The accounts for which the fee status will be updated
     */
    function markFeesAsPaidUpToID(uint256 upToId, address[] memory accounts) public onlyRole(FUND_ADMIN) {
        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 accountLastFeeIndex = lastFeeIndex[accounts[i]];
            require(upToId >= accountLastFeeIndex, "Invalid fee ID");
            if (upToId > accountLastFeeIndex) {
                lastFeeIndex[accounts[i]] = upToId;
                emit FeesWaived(accounts[i], upToId);
            }
        }
    }

    /**
     * @notice Distributes tokens among all token holders.
     *
     * @dev Only an account with the TOKEN_ADMIN role can call this function.
     * This operation is not supported for commit tokens.
     *
     * @param distType The type of distribution
     * @param amount The total amount of tokens to distribute
     * @param scale The scale factor for the distribution
     */
    function distribute(uint16 distId, string calldata distType, uint256 amount, uint8 scale)
        external
        onlyRole(TOKEN_ADMIN)
    {
        // @todo scale is probably useless
        require(!isCommitToken, "This operation is not supported for commit tokens");
        require(totalSupply() > 0, "No holders to distribute to");

        uint256 scaledAmount = amount * scale;
        uint256 scaledShare = scaledAmount / totalSupply();
        require(scaledShare > 0, "Invalid distribution");

        distributions.push(Distribution(scaledShare, distId, scale, distType));
        totalDistributionAmount += amount;

        require(usdc.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");
        emit DistributionAdded(distId, distType, amount, scale);
    }

    /**
     * @notice Function to confirm a pending distribution for an account.
     * @param account The account confirming the distribution.
     * @param distId The ID of the distribution to confirm.
     */
    function confirmDistribution(address account, uint16 distId) external onlyRole(TOKEN_ADMIN) {
        require(_getPendingDistribution(account, distId) > 0, "No pending distributions for this account and ID");
        confirmedDistributions[account][distId] = true;
        emit DistributionConfirmed(account, distId);
    }

    /**
     * @notice Cancel a distribution for a specific account. Transfers the USDC back to the fund.
     * @param account The account to cancel the distribution for.
     * @param distId The ID of the distribution to cancel.
     */
    function cancelDistribution(address account, uint16 distId) external onlyRole(TOKEN_ADMIN) {
        uint256 pendingDist = _getPendingDistribution(account, distId);
        require(pendingDist > 0, "No pending distribution to cancel");

        snapshotBalances[account][distId] = 0;
        totalDistributionAmount -= pendingDist;

        require(usdc.transfer(msg.sender, pendingDist), "USDC transfer failed");
        emit DistributionCancelled(account, distId);
    }

    /**
     * @dev Function to collect all the fees.
     *
     * @notice This function transfers the total fees paid to the caller (TOKEN_ADMIN)
     */
    function collectFees() external onlyRole(TOKEN_ADMIN) {
        require(feesPaid > 0, "No fees to collect");

        uint256 feesToCollect = feesPaid;
        feesPaid = 0;

        require(usdc.transfer(msg.sender, feesToCollect), "USDC transfer failed");
    }

    /**
     * @notice Pauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `TOKEN_ADMIN` role.
     */
    function pause() external onlyRole(TOKEN_ADMIN) {
        _pause();
    }

    /**
     * @notice Unpauses all token transfers.
     *
     * Requirements:
     *
     * - the caller must have the `TOKEN_ADMIN` role.
     */
    function unpause() external onlyRole(TOKEN_ADMIN) {
        _unpause();
    }

    /* ========== INTERNAL ========== */

    /**
     * @dev Calculate fee amount for a specific feeId for an account.
     * @param account Account to calculate the fee for.
     * @param feeId ID of the fee to calculate.
     */
    function _calculateFee(address account, uint256 feeId) private view returns (uint256) {
        Fee memory fee = fees[feeId];
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
    function _getPendingDistribution(address account, uint256 distId) private view returns (uint256) {
        uint256 snapshotBalance = snapshotBalances[account][distId];
        Distribution memory dist = distributions[distId];
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
        uint256 currentDistSnapshotIndex = distributions.length;
        uint256 lastDistSnapshotIndex = lastDistributionIndex[account];

        // If the distribution snapshot index is outdated, update it
        if (currentDistSnapshotIndex != lastDistSnapshotIndex) {
            snapshotBalances[account][currentDistSnapshotIndex] = balanceOf(account);
            lastDistributionIndex[account] = currentDistSnapshotIndex;
        }
        uint256 currentFeeSnapshotIndex = fees.length;
        uint256 lastFeeSnapshotIndex = lastFeeIndex[account];

        // If the fee snapshot index is outdated, update it
        if (currentFeeSnapshotIndex != lastFeeSnapshotIndex) {
            snapshotBalances[account][currentFeeSnapshotIndex] = balanceOf(account);
            lastFeeIndex[account] = currentFeeSnapshotIndex;
        }
    }
}
