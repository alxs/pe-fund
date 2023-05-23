// SPDX-License-Identifier: UNLICENSED
// https://github.com/crytic/slither/wiki/Detector-Documentation#recommendation-72
pragma solidity 0.8.18; // do not change, see ^

import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/IFundToken.sol";
import "../fund_tokens/FundToken.sol";
import "./Expenses.sol";
import "./Fees.sol";
import "./CapitalCalls.sol";
import "./Distributions.sol";
import "./Commitments.sol";
import "./Deployments.sol";
import "./Redemptions.sol";
import "./InterestPayments.sol";

/**
 * @title Fund contract
 * @notice Extends AccessControl, ERC20Pausable, and several other contracts.
 * The contract manages the funds and permissions of users.
 */
contract Fund is
    AccessControl,
    Pausable,
    Expenses,
    CapitalCalls,
    Distributions,
    Commitments,
    Fees,
    Deployments,
    Redemptions,
    InterestPayments
{
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");

    IComplianceRegistry public registry;
    IFundToken public gpCommitToken;
    IFundToken public lpCommitToken;
    IFundToken public gpFundToken;
    IFundToken public lpFundToken;

    string public name;
    uint8 public scale;
    uint256 public mgtFee;
    uint32 public initialClosing;
    uint32 public finalClosing;
    uint32 public commitmentDate;
    uint32 public endDate;

    uint256 public lpReturn;
    uint256 public gpReturn;
    uint256 public gpCatchup;
    uint256 public gpClawbackPerc;

    /**
     * @param registryAddress_ Address of the compliance registry contract.
     * @param initialClosing_ Initial closing time of the fund.
     * @param finalClosing_ Final closing time of the fund.
     * @param endDate_ End date of the fund.
     * @param commitmentDate_ Commitment date of the fund.
     * @param deploymentStart_ Deployment start time of the fund.
     * @param blockSize_ Size of blocks for commits.
     */
    constructor(
        string memory name_,
        address registryAddress_,
        address usdc_,
        uint32 initialClosing_,
        uint32 finalClosing_,
        uint32 endDate_,
        uint32 commitmentDate_,
        uint32 deploymentStart_,
        uint256 blockSize_,
        uint8 scale_,
        uint256 price_,
        uint256 prefRate_,
        InterestPayments.CompoundingPeriod compoundingInterval_,
        uint8 gpClawback_,
        uint8 carriedInterest_,
        uint8 managementFee_
    )
        Commitments(blockSize_, price_)
        Fees(prefRate_, gpClawback_, carriedInterest_, managementFee_)
        InterestPayments(compoundingInterval_)
    {
        name = name_;
        registry = IComplianceRegistry(registryAddress_);
        initialClosing = initialClosing_;
        finalClosing = finalClosing_;
        commitmentDate = commitmentDate_;
        endDate = endDate_;
        deploymentStart = deploymentStart_;
        blockSize = blockSize_;
        scale = scale_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FUND_ADMIN, msg.sender);

        _initTokens(usdc_);
    }

    function _initTokens(address usdc) private {
        gpCommitToken =
        new FundToken(registry, usdc, msg.sender, true, string.concat(name, " - GP Commit Token"), string.concat(name, "_GPCT"));
        gpFundToken =
        new FundToken(registry, usdc, msg.sender, false,string.concat(name, " - GP Fund Token"), string.concat(name, "_GFT"));

        lpCommitToken =
        new FundToken(registry, usdc,msg.sender, true, string.concat(name, " - LP Commit Token"), string.concat(name, "_LPCT"));
        lpFundToken =
        new FundToken(registry, usdc, msg.sender, false,   string.concat(name, " - LP Fund Token"), string.concat(name, "_LFT"));
    }

    /**
     * @notice Retrieves the LP return.
     * @return The LP return.
     */

    function getLpReturn() public view returns (uint256) {
        return lpReturn;
    }

    /**
     * @notice Sets the LP return to a new value.
     * @param _value New value for the LP return.
     */
    function setLpReturn(uint256 _value) private {
        lpReturn = _value;
    }

    /**
     * @notice Adds the specified value to the LP return.
     * @param _value The value to add to the LP return.
     */
    function addLpReturn(uint256 _value) public {
        uint256 newValue = lpReturn + _value;
        setLpReturn(newValue);
    }

    /**
     * @notice Retrieves the GP return.
     * @return The GP return.
     */
    function getGpReturn() public view returns (uint256) {
        return gpReturn;
    }

    /**
     * @dev Sets the GP return to a new value.
     * @param _value New value for the GP return.
     */
    function setGpReturn(uint256 _value) private {
        gpReturn = _value;
    }

    /**
     * @notice Adds the specified value to the GP return.
     * @param _value The value to add to the GP return.
     */
    function addGpReturn(uint256 _value) public {
        uint256 v = gpReturn + _value; // This will automatically revert on overflow
        setGpReturn(v);
    }

    /**
     * @notice Sets the GP catchup to the specified value.
     * @param _value The new value for the GP catchup.
     */
    function setGpCatchup(uint256 _value) private {
        gpCatchup = _value;
    }

    /**
     * @notice Adds the specified value to the GP catchup.
     * @param _value The value to add to the GP catchup.
     */
    function addGpCatchup(uint256 _value) public onlyRole(FUND_ADMIN) {
        uint256 catchup = gpCatchup + _value; // This will automatically revert on overflow
        setGpCatchup(catchup);
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
     * @notice Allows to commit LP funds to the contract.
     * @dev The user must be compliant and the commit size must be valid.
     * @param account The address of the user committing the funds.
     * @param amount The amount of funds to commit.
     * @param time The time of the commit.
     */
    function commit(address account, uint256 amount, uint32 time) public onlyRole(FUND_ADMIN) {
        require(time <= finalClosing, "Too late to commit");
        // Ensure user can commit
        require(registry.isCompliant(account), "Account is not compliant");

        // Validate the size..
        // amount must be a multiple of blockSize
        require(amount % blockSize == 0, "Invalid commit size");

        // Finally add this..
        _addLpCommitment(account, amount, time);
    }

    /**
     * @dev Approves multiple LP commitments.
     * @param accounts Array of account addresses to approve.
     * @param time Approval timestamp.
     */
    function approveCommits(address[] calldata accounts, uint32 time) external onlyRole(FUND_ADMIN) {
        _approveLpCommitments(accounts, time, lpCommitToken);
    }

    /**
     * @notice Allows the fund admin to cancel a commit.
     * @dev This function cancels the commitment for the user.
     * @param account Address of the account for which the commit will be canceled.
     * @param time The time of the commit to cancel.
     */
    function cancelCommit(address account, uint32 time) public onlyRole(FUND_ADMIN) {
        _cancelLpCommitment(account, time);
    }

    /**
     * @notice Issues a GP commit.
     * @dev This function adds a GP commitment and mints a GP commit token.
     * @param account The address to which the commit token should be issued.
     * @param amount The amount of the commit token to issue.
     * @param time The time of the commit.
     */
    function issueGpCommit(address account, uint256 amount, uint32 time) public onlyRole(FUND_ADMIN) {
        _addGpCommitment(account, amount, time);

        gpCommitToken.mint(account, amount);
    }

    /**
     * @notice Executes a capital call to draw down committed capital from LPs and GPs.
     * @dev Computes and assigns the scaled share of the capital call to each LP and GP.
     *      Ensures the requested amount is less than or equal to the remaining committed capital.
     *      Only accounts with the FUND_ADMIN role can call this function.
     * @param amount The amount of capital to be called in wei.
     * @param drawdownType Describes the type of drawdown.
     * @param time The timestamp of the capital call.
     */
    function capitalCall(uint256 amount, string memory drawdownType, uint32 time)
        public
        onlyRole(FUND_ADMIN)
        returns (uint16 callId)
    {
        // Validate the amount against remaining committed capital
        uint256 left = totalCommitted() - totalCalled;
        require(left >= amount, "FundError: Insufficient commits");

        // Record the capital call
        callId = _addCapitalCall(amount, drawdownType, time);

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
        _addInflow(amount, scale, prefRate, time, compoundingInterval);
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
     * @param price The conversion price from commit tokens to fund tokens.
     */
    function capitalCallDone(uint16 callId, address account, uint256 price) public {
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
        uint256 tokenAmount = acc.amount / price;

        // Ensure the account has enough commit tokens to burn
        require(commitToken.balanceOf(account) >= tokenAmount, "Insufficient commit token balance.");

        // Burn commit tokens from the account's balance
        commitToken.burnFrom(account, tokenAmount);

        // Mint an equal amount of fund tokens to the account
        fundToken.mint(account, tokenAmount);

        // Mark the capital call as done and update the timestamp
        acc.isDone = true;
        acc.timestamp = uint32(block.timestamp);

        // Emit an event to signal that the capital call has been finalized
        emit AccountCapitalCallDone(callId, account);
    }

    /**
     * @notice Charges a management fee to LPs based on their current lpCommitToken balance.
     * @dev Records the fee request and charges the management fee for all LP contracts.
     *      Only accounts with the FUND_ADMIN role can call this function.
     */
    function chargeManagementFee() public onlyRole(FUND_ADMIN) {
        // Record the current block timestamp
        uint32 time = uint32(block.timestamp);

        // Record the fee request
        uint16 id = addFeeRequest(managementFee, time);

        // Trigger the charge of the management fee
        lpCommitToken.chargeManagementFee(managementFee, id, price, time);
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
        // Record the distribution and update total distribution
        uint16 distId = _addDistribution(amount, distributionType, time);
        totalDistribution += amount;

        // Set carried interest
        uint256 carry = carriedInterest;

        // Calculate distribution amounts and update the distribution info
        (uint256 distributionAmount, uint256 capitalPaid, uint256 interestPaid) =
            _addOutflow(amount, scale, prefRate, time, compoundingInterval);

        // Compute LP's distribution and update GP's catchup if interest is paid
        uint256 lpDist = capitalPaid + interestPaid;
        if (interestPaid > 0) {
            addGpCatchup((interestPaid * carry) / 1000);
        }

        // Get total catchup and process the distributions if distribution amount is less or equal to total catchup
        uint256 totalCatchup = gpCatchup;
        if (distributionAmount <= totalCatchup) {
            if (lpDist > 0) {
                _processDistribution(lpFundToken, distributionType, time, distId, lpDist, scale);
                addLpReturn(lpDist);
            }

            if (distributionAmount > 0) {
                _processDistribution(gpFundToken, distributionType, time, distId, distributionAmount, scale);
                addGpReturn(distributionAmount);
                setGpCatchup(totalCatchup - distributionAmount);
            }
            return;
        }

        // Calculate GP's distribution and adjust distribution amount and GP catchup
        uint256 gpDist = totalCatchup;
        if (totalCatchup > 0) {
            setGpCatchup(0);
            distributionAmount -= totalCatchup;
        }

        // Calculate final distribution amounts and process them
        uint256 gpSplit = (distributionAmount * carry) / 1000;
        gpDist += gpSplit;
        lpDist += distributionAmount - gpSplit;
        if (gpDist > 0) {
            _processDistribution(gpFundToken, distributionType, time, distId, gpDist, scale);
            addGpReturn(gpDist);
        }

        if (lpDist > 0) {
            _processDistribution(lpFundToken, distributionType, time, distId, lpDist, scale);
            addLpReturn(lpDist);
        }
    }

    /**
     * @notice Adds a new redemption.
     * @dev Checks if the account is compliant and adds a redemption request.
     *      The function does not execute the redemption.
     * @param account The address of the account requesting the redemption.
     * @param amount The amount of tokens to be redeemed in wei.
     * @param time The timestamp of the redemption request.
     */
    function redeem(address account, uint256 amount, uint32 time) public onlyRole(FUND_ADMIN) {
        // Validate the compliance of the account
        require(registry.isCompliant(account), "Account is not compliant");

        // Add the redemption request
        addRedemption(account, amount, time);
    }

    // @inheritdoc
    function cancelRedemption(address account, uint32 time) public override {
        require(msg.sender == account, "Only the account owner can cancel redemption");
        super.cancelRedemption(account, time);
    }

    // @inheritdoc
    function addRedemption(address account, uint256 amount, uint32 time) public override onlyRole(FUND_ADMIN) {
        super.addRedemption(account, amount, time);
    }

    // @inheritdoc
    function approveRedemption(address account, uint32 time) public override onlyRole(FUND_ADMIN) {
        super.approveRedemption(account, time);

        // burnFrom checks caller has TOKEN_ADMIN role
        lpFundToken.burnFrom(account, redemptions[account].amount);
    }

    // @inheritdoc
    function rejectRedemption(address account, uint32 time) public override onlyRole(FUND_ADMIN) {
        super.rejectRedemption(account, time);
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
}
