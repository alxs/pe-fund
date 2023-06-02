// SPDX-License-Identifier: UNLICENSED
// https://github.com/crytic/slither/wiki/Detector-Documentation#recommendation-72
pragma solidity 0.8.18; // do not change, see ^

import "openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/IFundToken.sol";
import "../fund_tokens/FundToken.sol";
import "./CapitalCallsManager.sol";
import "./CommitmentManager.sol";
import "./RedemptionManager.sol";
import "./InterestPayments.sol";

/**
 * @title Fund contract
 * @notice Extends AccessControl, ERC20Pausable, and several other contracts.
 * The contract manages the funds and permissions of users.
 */
contract Fund is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    CommitmentManager,
    CapitalCallsManager,
    RedemptionManager,
    InterestPayments
{
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");

    IComplianceRegistry public registry;
    IFundToken public gpCommitToken;
    IFundToken public lpCommitToken;
    IFundToken public gpFundToken;
    IFundToken public lpFundToken;

    // Fund details
    string public name;
    uint8 public scale;
    uint32 public initialClosing;
    uint32 public finalClosing;
    uint32 public commitmentDate;
    uint32 public endDate;

    // Fee structure details
    uint256 public prefRate;
    uint8 public managementFee;

    // Distributions
    uint8 public carriedInterest;
    uint256 public distributionCount;
    uint256 public totalDistributed;

    // Financial data
    CompoundingPeriod public compoundingInterval;
    uint256 public blockSize;
    uint256 public price;
    uint256 public lpReturn;
    uint256 public gpReturn;
    uint256 public gpCatchup;
    uint8 public gpClawback; // @todo no functionality

    // Event declarations
    event Distribution(uint256 indexed distId, string distType, uint256 amount, uint8 scale);
    event ManagementFee(uint8 fee, uint256 price);

    /* ========== INITIALISATION ========== */

    constructor() {
        _disableInitializers();
    }

    /**
     * @param registryAddress_ Address of the compliance registry contract.
     * @param initialClosing_ Initial closing time of the fund.
     * @param finalClosing_ Final closing time of the fund.
     * @param endDate_ End date of the fund.
     * @param commitmentDate_ Commitment date of the fund.
     * @param blockSize_ Size of blocks for commits.
     */
    function initialize(
        string memory name_,
        address registryAddress_,
        address usdc_,
        uint32 initialClosing_,
        uint32 finalClosing_,
        uint32 endDate_,
        uint32 commitmentDate_,
        uint256 blockSize_,
        uint8 scale_,
        uint256 price_,
        uint256 prefRate_,
        CompoundingPeriod compoundingInterval_,
        uint8 gpClawback_,
        uint8 carriedInterest_,
        uint8 managementFee_
    ) public initializer {
        __AccessControl_init();
        __Pausable_init();

        blockSize = blockSize_;
        price = price_;
        name = name_;
        registry = IComplianceRegistry(registryAddress_);
        initialClosing = initialClosing_;
        finalClosing = finalClosing_;
        commitmentDate = commitmentDate_;
        endDate = endDate_;
        blockSize = blockSize_;
        scale = scale_;
        prefRate = prefRate_;
        gpClawback = gpClawback_;
        carriedInterest = carriedInterest_;
        managementFee = managementFee_;
        compoundingInterval = compoundingInterval_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FUND_ADMIN, msg.sender);

        _initTokens(usdc_);
    }

    function _initTokens(address usdc) private onlyInitializing {
        gpCommitToken =
        new FundToken(registry, usdc, msg.sender, true, string.concat(name, " - GP Commit Token"), string.concat(name, "_GPCT"));
        gpFundToken =
        new FundToken(registry, usdc, msg.sender, false,string.concat(name, " - GP Fund Token"), string.concat(name, "_GFT"));

        lpCommitToken =
        new FundToken(registry, usdc,msg.sender, true, string.concat(name, " - LP Commit Token"), string.concat(name, "_LPCT"));
        lpFundToken =
        new FundToken(registry, usdc, msg.sender, false,   string.concat(name, " - LP Fund Token"), string.concat(name, "_LFT"));
    }

    /* ========== MUTATIVE ========== */

    /**
     * @notice Allows to commit LP funds to the contract.
     * @dev The user must be compliant and the commit size must be valid.
     * @param amount The amount of funds to commit.
     */
    function commit(uint256 amount) public {
        require(block.timestamp <= finalClosing, "Too late to commit");
        _addLpCommitment(msg.sender, amount);
    }

    /**
     * @notice Allows LPs to cancel a commitment.
     */
    function cancelCommit() public {
        _cancelLpCommitment(msg.sender);
    }

    /**
     * @notice Allows users to cancel a redemption.
     */
    function cancelRedemption() public {
        _cancelRedemption(msg.sender);
    }

    /* ========== RESTRICTED ========== */

    /**
     * @notice Allows the fund admin to add an LP commitment.
     * @dev The user must be compliant and the commit size must be valid.
     * @param account The address of the user committing the funds.
     * @param amount The amount of funds to commit.
     */
    function addLpCommit(address account, uint256 amount) public onlyRole(FUND_ADMIN) {
        _addLpCommitment(account, amount);
    }

    /**
     * @notice Allows the fund admin to cancel an LP commitment.
     * @dev This function cancels the commitment for the user.
     * @param account Address of the account for which the commit will be canceled.
     */

    function cancelCommit(address account) public onlyRole(FUND_ADMIN) {
        _cancelLpCommitment(account);
    }

    /**
     * @dev Approves multiple LP commitments.
     * @param accounts Array of account addresses to approve.
     */
    function approveCommits(address[] calldata accounts) external onlyRole(FUND_ADMIN) {
        _approveLpCommitments(accounts, lpCommitToken, price);
    }

    /**
     * _setLpCommitment
     * @notice Issues a GP commit.
     * @dev This function adds a GP commitment and mints a GP commit token.
     * @param account The address to which the commit token should be issued.
     * @param amount The amount of the commit token to issue.
     */
    function issueGpCommit(address account, uint256 amount) public onlyRole(FUND_ADMIN) {
        _addGpCommitment(account, amount);

        gpCommitToken.mint(account, amount);
    }

    /**
     * @notice Executes a capital call to draw down committed capital from LPs and GPs.
     * @dev Computes and assigns the scaled share of the capital call to each LP and GP.
     *      Ensures the requested amount is less than or equal to the remaining committed capital.
     *      Only accounts with the FUND_ADMIN role can call this function.
     * @param amount The amount of capital to be called in wei.
     * @param drawdownType Describes the type of drawdown.
     */
    function capitalCall(uint256 amount, string memory drawdownType)
        public
        onlyRole(FUND_ADMIN)
        returns (uint16 callId)
    {
        // Validate the amount against remaining committed capital
        uint256 left = totalCommitted() - totalCalled;
        require(left >= amount, "FundError: Insufficient commits");

        // Record the capital call
        callId = _addCapitalCall(amount, drawdownType);

        // Scale the requested amount to share among LPs and GPs
        uint256 scaledAmount = amount * scale;
        uint256 scaledShare = scaledAmount / totalCommitted();
        require(scaledShare > 0, "FundError: Scale overflow");

        // Compute and assign the share for each GP
        for (uint256 i = 0; i < gpAccounts.length; i++) {
            Commit memory gpCommit = gpCommitments[gpAccounts[i]];
            uint256 ss = scaledShare * gpCommit.amount;
            uint256 share = ss / scale;
            require(share != 0, "FundError: Invalid share");

            _addAccountCapitalCall(callId, gpAccounts[i], share, AccountType.GP);
        }

        // Compute and assign the share for each LP
        for (uint256 i = 0; i < lpAccounts.length; i++) {
            Commit memory lpCommit = lpCommitments[lpAccounts[i]];
            uint256 ss = scaledShare * lpCommit.amount;
            require(ss / scale > 0, "FundError: Scale overflow");
            uint256 share = ss / scale;
            require(share != 0, "FundError: Invalid share");

            _addAccountCapitalCall(callId, lpAccounts[i], share, AccountType.LP);
        }

        // Update the total amount called
        totalCalled += amount;

        // Record the capital inflow
        _addInflow(amount, scale, prefRate, block.timestamp, compoundingInterval);
    }

    /**
     * @dev Handles the finalization of a capital call.
     * This function should be called after the capital call has been satisfied.
     * The function burns the necessary amount of commit tokens from the account's balance and mints an equal amount of fund tokens.
     *
     * Requirements:
     * - The account type must be either GP or LP.
     * - The account must have a sufficient balance of the relevant commit tokens.
     *
     * @param callId The ID of the capital call.
     * @param account The address of the account satisfying the capital call.
     * @param callPrice The conversion price from commit tokens to fund tokens.
     */
    function capitalCallDone(uint16 callId, address account, uint256 callPrice) public onlyRole(FUND_ADMIN) {
        // Access the account's capital call info using the account address and call ID
        AccountCapitalCall storage acc = accountCapitalCalls[account][callId];

        // Ensure the account type is either GP or LP
        require(acc.accountType == AccountType.GP || acc.accountType == AccountType.LP, "Invalid account type.");

        // Determine which pair of commit and fund tokens to use based on the account type
        IFundToken commitToken;
        IFundToken fundToken;
        if (acc.accountType == AccountType.GP) {
            commitToken = gpCommitToken;
            fundToken = gpFundToken;
        } else {
            // acc.accountType == AccountType.LP
            commitToken = lpCommitToken;
            fundToken = lpFundToken;
        }

        // Calculate the amount of tokens to burn/mint
        uint256 tokenAmount = acc.amount / callPrice;

        // Ensure the account has enough commit tokens to burn
        require(commitToken.balanceOf(account) >= tokenAmount, "Insufficient commit token balance.");

        // Burn commit tokens from the account's balance
        commitToken.burnFrom(account, tokenAmount);

        // Mint an equal amount of fund tokens to the account
        fundToken.mint(account, tokenAmount);

        // Mark the capital call as done and update the timestamp
        acc.isDone = true;

        // Emit an event to signal that the capital call has been finalized
        emit AccountCapitalCallDone(callId, account);
    }

    /**
     * @notice Charges a management fee to LPs based on their current lpCommitToken balance.
     * @dev Records the fee request and charges the management fee for all LP contracts.
     *      Only accounts with the FUND_ADMIN role can call this function.
     */
    function chargeManagementFee() public onlyRole(FUND_ADMIN) {
        lpCommitToken.chargeManagementFee(managementFee, price);
        emit ManagementFee(managementFee, price);
    }

    /**
     * @notice Distributes the funds among the fund stakeholders.
     * @dev Calculates the distribution amounts considering carried interest, then processes them.
     *      The function handles distributions in cases where the distribution amount is less than,
     *      equal to, or greater than the GP's catch-up.
     *      Only accounts with the FUND_ADMIN role can call this function.
     * @param amount The total amount to distribute in wei.
     * @param distributionType Describes the type of distribution.
     * @param time The timestamp of the distribution.
     */
    function distribute(uint256 amount, string calldata distributionType, uint32 time) public onlyRole(FUND_ADMIN) {
        // Update total distribution and distribution count
        uint256 distId = ++distributionCount;
        totalDistributed += amount;

        // Set carried interest
        uint256 carry = carriedInterest;

        // Calculate distribution amounts and update the distribution info
        (uint256 distributionAmount, uint256 capitalPaid, uint256 interestPaid) =
            _addOutflow(amount, scale, prefRate, time, compoundingInterval);

        // Compute LP's distribution and update GP's catchup if interest is paid
        uint256 lpDist = capitalPaid + interestPaid;
        if (interestPaid > 0) {
            gpCatchup += (interestPaid * carry) / 1000;
        }

        // Get total catchup and process the distributions if distribution amount is less or equal to total catchup
        uint256 totalCatchup = gpCatchup;
        if (distributionAmount <= totalCatchup) {
            if (lpDist > 0) {
                _processDistribution(lpFundToken, distributionType, distId, lpDist);
                lpReturn += lpDist;
            }

            if (distributionAmount > 0) {
                _processDistribution(gpFundToken, distributionType, distId, distributionAmount);
                gpReturn += distributionAmount;
                gpCatchup = totalCatchup - distributionAmount;
            }
            return;
        }

        // Calculate GP's distribution and adjust distribution amount and GP catchup
        uint256 gpDist = totalCatchup;
        if (totalCatchup > 0) {
            gpCatchup = 0;
            distributionAmount -= totalCatchup;
        }

        // Calculate final distribution amounts and process them
        uint256 gpSplit = (distributionAmount * carry) / 1000;
        gpDist += gpSplit;
        lpDist += distributionAmount - gpSplit;
        if (gpDist > 0) {
            _processDistribution(gpFundToken, distributionType, distId, gpDist);
            gpReturn += gpDist;
        }

        if (lpDist > 0) {
            _processDistribution(lpFundToken, distributionType, distId, lpDist);
            lpReturn += lpDist;
        }

        emit Distribution(distId, distributionType, amount, scale);
    }

    /**
     * @notice Allows to add a new redemption. Requires the account to be compliant.
     * @dev Checks if the account is compliant and adds a redemption request.
     *      The function does not execute the redemption.
     *      Only accounts with the FUND_ADMIN role can call this function.
     * @param account The address of the account requesting the redemption.
     * @param amount The amount of tokens to be redeemed in wei.
     */
    function addRedemption(address account, uint256 amount) public onlyRole(FUND_ADMIN) {
        // Validate the compliance of the account
        require(registry.isCompliant(account), "Account is not compliant");

        // Add the redemption request
        _addRedemption(account, amount);
    }

    /**
     * @notice Cancel the redemption for a specific account.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param account The account whose redemption will be cancelled.
     */
    function cancelRedemption(address account) public onlyRole(FUND_ADMIN) {
        require(msg.sender == account, "Only the account owner can cancel redemption");
        _cancelRedemption(account);
    }

    /**
     * @notice Approve the redemption for a specific account.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * Burns the amount of lpFundToken from the account equal to its redemption amount.
     * @param account The account whose redemption will be approved.
     */
    function approveRedemption(address account) public onlyRole(FUND_ADMIN) {
        _approveRedemption(account);

        lpFundToken.burnFrom(account, redemptions[account].amount);
    }

    /**
     * @notice Reject the redemption for a specific account.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param account The account whose redemption will be rejected.
     */
    function rejectRedemption(address account) public onlyRole(FUND_ADMIN) {
        _rejectRedemption(account);
    }

    /**
     * @notice Sets the initial closing time of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _initialClosing The new initial closing time.
     */
    function setInitialClosing(uint32 _initialClosing) public onlyRole(FUND_ADMIN) {
        initialClosing = _initialClosing;
    }

    /**
     * @notice Sets the final closing time of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _finalClosing The new final closing time.
     */
    function setFinalClosing(uint32 _finalClosing) public onlyRole(FUND_ADMIN) {
        finalClosing = _finalClosing;
    }

    /**
     * @notice Sets the end date of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _endDate The new end date.
     */
    function setEndDate(uint32 _endDate) public onlyRole(FUND_ADMIN) {
        endDate = _endDate;
    }

    /**
     * @notice Sets the commitment date of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _commitmentDate The new commitment date.
     */
    function setCommitmentDate(uint32 _commitmentDate) public onlyRole(FUND_ADMIN) {
        commitmentDate = _commitmentDate;
    }

    /**
     * @notice Sets the block size for commits.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _blockSize The new block size.
     */
    function setBlockSize(uint256 _blockSize) public onlyRole(FUND_ADMIN) {
        blockSize = _blockSize;
    }

    /**
     * @notice Updates the preferred rate
     * @dev Only accessible internally
     * @param _prefRate The new preferred rate to be set
     */
    function setPrefRate(uint256 _prefRate) public onlyRole(FUND_ADMIN) {
        prefRate = _prefRate;
    }

    /**
     * @notice Updates the GP Clawback rate
     * @param _gpClawback The new GP Clawback rate to be set
     */
    function setGPClawback(uint8 _gpClawback) public onlyRole(FUND_ADMIN) {
        gpClawback = _gpClawback;
    }

    /**
     * @notice Updates the carried interest rate
     * @param _carriedInterest The new carried interest rate to be set
     */
    function setCarriedInterest(uint8 _carriedInterest) public onlyRole(FUND_ADMIN) {
        carriedInterest = _carriedInterest;
    }

    /**
     * @notice Updates the management fee
     * @param _managementFee The new management fee to be set
     */
    function setManagementFee(uint8 _managementFee) public onlyRole(FUND_ADMIN) {
        managementFee = _managementFee;
    }

    /**
     * @notice Pauses all token transfers in associated tokens.
     * The caller must have the FUND_ADMIN role.
     */
    function pauseTokens() public onlyRole(FUND_ADMIN) {
        gpCommitToken.pause();
        lpCommitToken.pause();
        gpFundToken.pause();
        lpFundToken.pause();
    }

    /**
     * @notice Unpauses token transfers in associated tokens.
     * The caller must have the FUND_ADMIN role.
     */
    function unpauseTokens() public onlyRole(FUND_ADMIN) {
        gpCommitToken.unpause();
        lpCommitToken.unpause();
        gpFundToken.unpause();
        lpFundToken.unpause();
    }

    /* ========== INTERNAL ========== */

    /**
     * @dev Adds a new LP commitment.
     * @param account Address of the account.
     * @param amount Commitment amount.
     */
    function _addLpCommitment(address account, uint256 amount) internal {
        // Ensure user can commit
        require(registry.isCompliant(account), "Account is not compliant");

        // Validate the size - amount must be a multiple of blockSize
        // @todo not for GPs?
        require(amount % blockSize == 0, "Invalid commit size");

        _setLpCommitment(account, amount);
    }

    /**
     * @notice Executes a distribution via an IFundToken contract
     * @dev Invokes the distribute function of a specified IFundToken contract
     * @param token The address of the IFundToken contract to be interfaced with
     * @param distributionType The category of the distribution
     * @param distId The ID assigned to the distribution
     * @param amount The volume to be distributed
     */
    function _processDistribution(IFundToken token, string calldata distributionType, uint256 distId, uint256 amount)
        internal
    {
        require(distId < type(uint16).max, "Distribution ID exceeds uint16");
        IFundToken(token).distribute(uint16(distId), distributionType, amount, scale);
    }
}
