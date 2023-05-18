// SPDX-License-Identifier: UNLICENSED
// https://github.com/crytic/slither/wiki/Detector-Documentation#recommendation-72
pragma solidity 0.8.18; // do not change, see ^

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/ISecurityToken.sol";
import "./DistributionManager.sol";
import "./FeeManager.sol";

/**
 * @title SecurityToken
 *
 * @notice A token contract for managing an asset with dividends and fees.
 *
 * The contract inherits from several libraries from OpenZeppelin,
 * as well as from two local contracts: DistributionManager and FeeManager.
 *
 * The SecurityToken contract itself implements a security token that has the capability to pause,
 * manage roles, mint, burn, and distribute tokens. It can also charge management fees.
 */
contract SecurityToken is
    ISecurityToken,
    ERC20Pausable,
    AccessControl,
    ReentrancyGuard,
    DistributionManager,
    FeeManager
{
    IComplianceRegistry public complianceRegistry;

    // Constants representing the different roles within the system
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");
    bytes32 public constant TOKEN_ADMIN = keccak256("TOKEN_ADMIN");
    bytes32 public constant DISTRIBUTOR = keccak256("DISTRIBUTOR");

    // Mappings for storing account related data
    mapping(address => uint256) private lastDistributionIndex;
    mapping(address => uint256) private lastFeeIndex;
    mapping(address => mapping(uint256 => uint256)) private snapshotBalances;

    // Boolean indicating whether or not this is a CommitToken
    bool public isCommitToken;

    /**
     * @notice Constructs the SecurityToken contract.
     *
     * @param complianceRegistry_ The address of the Compliance Registry contract
     * @param fundAdmin_ The address of the Fund Administrator
     * @param tokenAdmin_ The address of the Token Administrator
     * @param distributor_ The address of the Distributor
     * @param isCommitToken_ A boolean indicating whether this is a Commit Token
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     */
    constructor(
        address complianceRegistry_,
        address fundAdmin_,
        address tokenAdmin_,
        address distributor_,
        bool isCommitToken_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        complianceRegistry = IComplianceRegistry(complianceRegistry_);
        isCommitToken = isCommitToken_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FUND_ADMIN, fundAdmin_);
        _setupRole(TOKEN_ADMIN, tokenAdmin_);
        _setupRole(DISTRIBUTOR, distributor_);
    }

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
        noPendingFee(account)
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
     * @param ts The timestamp at which the fee was charged
     */
    function chargeManagementFee(uint8 mgtFee, uint256 price, uint64 ts) public onlyRole(FUND_ADMIN) {
        _addFee(mgtFee, price, ts);
    }

    /**
     * @notice Updates the fee status for a list of accounts.
     *
     * @dev Only an account with the FUND_ADMIN role can call this function.
     *
     * @param feeId The ID of the fee to update
     * @param status The status to update to
     * @param ts The timestamp at which the status was updated
     * @param accounts The accounts for which the fee status will be updated
     */
    function updateFeeStatus(uint32 feeId, uint8 status, uint64 ts, address[] memory accounts)
        public
        onlyRole(FUND_ADMIN)
    {
        _updateFeeStatus(feeId, accounts, ts, status);
    }

    /**
     * @notice Distributes tokens among all token holders.
     *
     * @dev Only an account with the DISTRIBUTOR role can call this function.
     * This operation is not supported for commit tokens.
     *
     * @param distId The ID of the distribution
     * @param distType The type of distribution
     * @param time The timestamp at which the distribution occurs
     * @param amount The total amount of tokens to distribute
     * @param scale The scale factor for the distribution
     */
    function distribute(uint32 distId, string memory distType, uint64 time, uint256 amount, uint256 scale)
        public
        onlyRole(DISTRIBUTOR)
    {
        require(!isCommitToken, "This operation is not supported for commit tokens");

        uint256 total = totalSupply();
        require(total > 0, "No holders to distribute to");

        uint256 scaledAmount = amount * scale;
        uint256 scaledShare = scaledAmount / total;
        require(scaledShare > 0, "Invalid distribution");

        _addDistribution(distId, amount, distType, time);
    }

    /* ========== INTERNAL ========== */

    /**
     * @notice Internal function that is called before any transfer of tokens. @todo this includes minting and burning.
     *
     * @dev Overridden from ERC20Pausable.
     * Ensures that the operation is compliant, updates snapshot balances, and checks for any pending fees or distributions.
     *
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param amount The amount of tokens to transfer
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
        noPendingFee(from)
        noPendingDistribution(from)
        nonReentrant
    {
        require(!isCommitToken, "This operation is not supported for commit tokens");

        // Ensure sender and recipient are compliant
        require(complianceRegistry.isCompliant(from), "Sender is not compliant");
        require(complianceRegistry.isCompliant(to), "Recipient is not compliant");

        updateSnapshot(from);
        updateSnapshot(to);
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @notice Updates the balance snapshot for an account.
     *
     * @dev If the snapshot index for distributions or fees does not match the account's last snapshot index, a new
     * snapshot is recorded with the current balance of the account.
     *
     * @param account The account for which to update the snapshot
     */
    function updateSnapshot(address account) private {
        uint32 currentSnapshotIndex = totalDistributions;
        uint256 lastSnapshotIndex = lastDistributionIndex[account];

        if (currentSnapshotIndex != lastSnapshotIndex) {
            uint256 balance = super.balanceOf(account);
            snapshotBalances[account][currentSnapshotIndex] = balance;
            lastDistributionIndex[account] = currentSnapshotIndex;
        }

        uint256 currentFeeSnapshotIndex = nextFeeId();
        uint256 lastFeeSnapshotIndex = lastFeeIndex[account];

        if (currentFeeSnapshotIndex != lastFeeSnapshotIndex) {
            uint256 balance = super.balanceOf(account);
            snapshotBalances[account][currentFeeSnapshotIndex] = balance;
            lastFeeIndex[account] = currentFeeSnapshotIndex;
        }
    }
}
