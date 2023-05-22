// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/IFundToken.sol";
import "./DistributionManager.sol";
import "./FeeManager.sol";

/**
 * @title FundToken
 *
 * @notice A token contract for managing an asset with dividends and fees.
 *
 * The contract inherits from several libraries from OpenZeppelin,
 * as well as from two local contracts: DistributionManager and FeeManager.
 *
 * The FundToken contract itself implements a security token that has the capability to pause,
 * manage roles, mint, burn, and distribute tokens. It can also charge management fees.
 */
contract FundToken is IFundToken, ERC20Pausable, AccessControl, ReentrancyGuard, DistributionManager, FeeManager {
    IComplianceRegistry public complianceRegistry;

    // Constants representing the different roles within the system
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");
    bytes32 public constant TOKEN_ADMIN = keccak256("TOKEN_ADMIN");

    // Mappings for storing account related data
    mapping(address => uint256) private lastDistributionIndex;
    mapping(address => uint256) private lastFeeIndex;
    mapping(address => mapping(uint256 => uint256)) private snapshotBalances;

    // Boolean indicating whether or not this is a CommitToken
    bool public isCommitToken;

    modifier noPendingFees(address account) {
        require(feeBalance(account) == 0, "Account has pending fees");
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
        address fundAdmin_,
        bool isCommitToken_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        complianceRegistry = complianceRegistry_;
        isCommitToken = isCommitToken_;

        _setupRole(DEFAULT_ADMIN_ROLE, fundAdmin_);
        _setupRole(FUND_ADMIN, fundAdmin_);
        _setupRole(TOKEN_ADMIN, msg.sender); // Fund contract
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Calculates the total unpaid fee balance for an account.
     * @param account Account to calculate the balance for.
     */
    function feeBalance(address account) public view returns (uint256) {
        uint256 totalFees = 0;
        for (uint256 i = lastFeeIndex[account]; i < fees.length; i++) {
            totalFees += calculateFee(account, i);
        }
        return totalFees;
    }

    /**
     * @dev Calculate fee amount for a specific feeId for an account.
     * @param account Account to calculate the fee for.
     * @param feeId ID of the fee to calculate.
     */
    function calculateFee(address account, uint256 feeId) public view returns (uint256) {
        Fee memory fee = fees[feeId];
        uint256 snapshotBalance = snapshotBalances[account][feeId];
        uint256 charge = fee.fee * snapshotBalance / fee.price; // Adjusted for the updated fee calculation

        return charge;
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
    function chargeManagementFee(uint8 mgtFee, uint256 id, uint256 price, uint256 timestamp)
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
    function markFeeAsPaid(uint32 feeId, address[] memory accounts) public onlyRole(FUND_ADMIN) {
        // Maybe emit event here instead of ts
        for (uint256 i = 0; i < accounts.length; i++) {
            paidFees[accounts[i]][feeId] = true;
        }
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
    function distribute(uint32 distId, string memory distType, uint256 time, uint256 amount, uint256 scale)
        public
        onlyRole(TOKEN_ADMIN)
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
        noPendingFees(from)
        noPendingDistribution(from)
        nonReentrant
    {
        require(!isCommitToken, "This operation is not supported for commit tokens");

        // Ensure sender and recipient are compliant
        require(complianceRegistry.isCompliant(from), "Sender is not compliant");
        require(complianceRegistry.isCompliant(to), "Recipient is not compliant");

        _updateSnapshot(from);
        _updateSnapshot(to);
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
    function _updateSnapshot(address account) private {
        uint32 currentSnapshotIndex = totalDistributions;
        uint256 lastSnapshotIndex = lastDistributionIndex[account];

        if (currentSnapshotIndex != lastSnapshotIndex) {
            uint256 balance = super.balanceOf(account);
            snapshotBalances[account][currentSnapshotIndex] = balance;
            lastDistributionIndex[account] = currentSnapshotIndex;
        }

        uint256 currentFeeSnapshotIndex = fees.length;
        uint256 lastFeeSnapshotIndex = lastFeeIndex[account];

        if (currentFeeSnapshotIndex != lastFeeSnapshotIndex) {
            uint256 balance = super.balanceOf(account);
            snapshotBalances[account][currentFeeSnapshotIndex] = balance;
            lastFeeIndex[account] = currentFeeSnapshotIndex;
        }
    }
}
