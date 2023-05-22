// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/ISecurityToken.sol";
import "../securityToken/SecurityToken.sol";
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
 * @dev Extends AccessControl, ERC20Pausable, and several other contracts.
 * The contract manages the funds and permissions of users.
 */
contract Fund is
    AccessControl,
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
    bytes32 public constant TOKEN_ADMIN = keccak256("TOKEN_ADMIN");

    IComplianceRegistry public registry;
    ISecurityToken public gpFundToken;
    ISecurityToken public lpFundToken;

    uint8 public scale;
    uint256 public size;
    uint256 public initialClosing;
    uint256 public finalClosing;
    uint256 public endDate;
    uint256 public gpClawbackPerc;
    uint256 public mgtFee;

    uint256 public commitmentDate;
    uint256 public lpReturn;
    uint256 public gpReturn;
    uint256 public gpCatchup;

    /**
     * @dev Constructor sets the initial properties of the contract.
     * @param registryAddress_ Address of the compliance registry contract.
     * @param initialClosing_ Initial closing time of the fund.
     * @param finalClosing_ Final closing time of the fund.
     * @param endDate_ End date of the fund.
     * @param commitmentDate_ Commitment date of the fund.
     * @param deploymentStart_ Deployment start time of the fund.
     * @param blockSize_ Size of blocks for commits.
     */
    constructor(
        address registryAddress_,
        address tokenAdmin_,
        uint256 initialClosing_,
        uint256 finalClosing_,
        uint256 endDate_,
        uint256 commitmentDate_,
        uint256 deploymentStart_,
        uint256 blockSize_,
        uint8 scale_,
        uint256 price_,
        uint256 prefRate_,
        uint8 compoundingInterval_,
        uint8 gpClawback_,
        uint8 carriedInterest_,
        uint8 managementFee_
    )
        Commitments(blockSize_, price_)
        Fees(prefRate_, compoundingInterval_, gpClawback_, carriedInterest_, managementFee_)
    {
        registry = IComplianceRegistry(registryAddress_);
        initialClosing = initialClosing_;
        finalClosing = finalClosing_;
        endDate = endDate_;
        commitmentDate = commitmentDate_;
        deploymentStart = deploymentStart_;
        blockSize = blockSize_;
        scale = scale_;

        _setupRole(FUND_ADMIN, msg.sender);
        _setupRole(TOKEN_ADMIN, tokenAdmin_);
    }

    /**
     * @notice Returns the LP return.
     * @dev This function allows to get the LP return.
     * @return lpReturn The LP return.
     */
    function getLpReturn() public view returns (uint256) {
        return lpReturn;
    }

    /**
     * @dev Sets the LP return to the specified value.
     * @param _value The new value for the LP return.
     */
    function setLpReturn(uint256 _value) private {
        lpReturn = _value;
    }

    /**
     * @notice Adds the specified value to the LP return.
     * @dev This function allows to increase the LP return.
     * @param _value The value to add to the LP return.
     */
    function addLpReturn(uint256 _value) public {
        uint256 v = lpReturn + _value; // This will automatically revert on overflow
        setLpReturn(v);
    }

    /**
     * @notice Returns the GP return.
     * @dev This function allows to get the GP return.
     * @return gpReturn The GP return.
     */
    function getGpReturn() public view returns (uint256) {
        return gpReturn;
    }

    /**
     * @dev Sets the GP return to the specified value.
     * @param _value The new value for the GP return.
     */
    function setGpReturn(uint256 _value) private {
        gpReturn = _value;
    }

    /**
     * @notice Adds the specified value to the GP return.
     * @dev This function allows to increase the GP return.
     * @param _value The value to add to the GP return.
     */
    function addGpReturn(uint256 _value) public {
        uint256 v = gpReturn + _value; // This will automatically revert on overflow
        setGpReturn(v);
    }

    /**
     * @notice Returns the GP catchup.
     * @dev This function allows to get the GP catchup.
     * @return gpCatchup The GP catchup.
     */
    function getGpCatchup() public view returns (uint256) {
        return gpCatchup;
    }

    /**
     * @dev Sets the GP catchup to the specified value.
     * @param _value The new value for the GP catchup.
     */
    function setGpCatchup(uint256 _value) private {
        gpCatchup = _value;
    }

    /**
     * @notice Adds the specified value to the GP catchup.
     * @dev This function allows to increase the GP catchup.
     * @param _value The value to add to the GP catchup.
     */
    function addGpCatchup(uint256 _value) public {
        uint256 catchup = gpCatchup + _value; // This will automatically revert on overflow
        setGpCatchup(catchup);
    }

    /**
     * @notice Sets the initial closing time of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _initialClosing The new initial closing time.
     */

    function setInitialClosing(uint256 _initialClosing) public onlyRole(FUND_ADMIN) {
        initialClosing = _initialClosing;
    }

    /**
     * @notice Sets the final closing time of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _finalClosing The new final closing time.
     */
    function setFinalClosing(uint256 _finalClosing) public onlyRole(FUND_ADMIN) {
        finalClosing = _finalClosing;
    }

    /**
     * @notice Sets the end date of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _endDate The new end date.
     */
    function setEndDate(uint256 _endDate) public onlyRole(FUND_ADMIN) {
        endDate = _endDate;
    }

    /**
     * @notice Sets the commitment date of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _commitmentDate The new commitment date.
     */
    function setCommitmentDate(uint256 _commitmentDate) public onlyRole(FUND_ADMIN) {
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
     * @notice Allows a user to commit funds to the contract.
     * @dev The user must be compliant and the commit size must be valid.
     * @param account The address of the user committing the funds.
     * @param amount The amount of funds to commit.
     * @param time The time of the commit.
     */
    function commit(address account, uint256 amount, uint256 time) public {
        // @todo these are only implemented for LPs
        require(time <= finalClosing, "Too late to commit");
        // Ensure user can commit
        require(registry.isCompliant(account), "Account is not compliant");

        // Validate the size..
        // amount must be a multiple of blockSize
        require(amount % blockSize == 0, "Invalid commit size");

        // Finally add this..
        addLpCommitment(account, amount, time);
    }

    /**
     * @notice Allows a user to cancel a commit.
     * @dev This function cancels the commitment for the user.
     * @param account The address of the user cancelling the commit.
     * @param time The time of the commit to cancel.
     */
    function cancelCommit(address account, uint256 time) public {
        cancelLpCommitment(account, time);
    }

    /**
     * @notice Issues a GP commit.
     * @dev This function adds a GP commitment and mints a GP commit token.
     * @param account The address to which the commit token should be issued.
     * @param amount The amount of the commit token to issue.
     * @param time The time of the commit.
     */
    function issueGpCommit(address account, uint256 amount, uint256 time) public {
        addGpCommitment(account, amount, time);

        // Assuming that the contract has the MINTER_ROLE of the gpCommitToken
        // @todo implement appropriate access control checks here
        gpCommitToken.mint(account, amount);
    }

    /**
     * @notice Executes a capital call to draw down committed capital from LPs and GPs.
     * @dev Only accounts with the FUND_ADMIN role can call this function.
     *      The function computes the scaled share for each LP and GP based on their commitments,
     *      and then adds the capital call to their account. Inflows are also added.
     * @param amount The amount of capital to be called.
     * @param drawdownType A string describing the type of drawdown.
     * @param time The timestamp when the capital call is made.
     */
    function capitalCall(uint256 amount, string memory drawdownType, uint256 time) public onlyRole(FUND_ADMIN) {
        // Check if there is enough committed capital
        uint256 totalCommitted = totalCommittedLp + totalCommittedGp;
        uint256 left = totalCommitted - totalCalled;
        require(left >= amount, "FundError: Insufficient Commits");

        // Record the capital call
        uint256 callId = addCapitalCall(amount, drawdownType, time, gpFundToken, lpFundToken);

        uint256 scaledAmount = amount * scale;

        require(scaledAmount / totalCommitted > 0, "FundError: Scale Overflow");
        uint256 scaledShare = scaledAmount / totalCommitted;

        for (uint256 i = 0; i < gpAccounts.length; i++) {
            Commit memory gpCommit = gpCommitments[gpAccounts[i]];
            uint256 ss = scaledShare * gpCommit.amount;
            uint256 share = ss / scale;
            require(share != 0, "FundError: Invalid Share");

            addAccountCapitalCall(callId, gpAccounts[i], share, AccountType.GP);
        }

        // And for each LP
        for (uint256 i = 0; i < lpAccounts.length; i++) {
            Commit memory lpCommit = lpCommitments[lpAccounts[i]];
            uint256 ss = scaledShare * lpCommit.amount;
            require(ss / scale > 0, "FundError: Scale Overflow");
            uint256 share = ss / scale;
            require(share != 0, "FundError: Invalid Share");

            addAccountCapitalCall(callId, gpAccounts[i], share, AccountType.GP);
        }

        // Update the total capital called
        totalCalled += amount;

        // Record the capital inflow
        addInflow(amount, scale, prefRate, time, compoundingInterval);
    }

    /**
     * @notice Triggers the charge of the management fee.
     * @dev Only accounts with the FUND_ADMIN role can call this function.
     *      The function records the fee request and then charges the management fee
     *      for all the LP contracts in the fund.
     */
    function chargeManagementFee() public onlyRole(FUND_ADMIN) {
        // Capture the current block timestamp
        uint256 time = block.timestamp;

        // Record the fee request and get the request ID
        uint256 id = addFeeRequest(managementFee, time);

        // Retrieve all the LP contracts associated with the fund
        ISecurityToken[] memory contracts = getFundContracts();

        // Charge the management fee for each LP contract
        // @todo why are there more than 2 LP contracts?
        for (uint256 i = 0; i < contracts.length; i++) {
            // Each contract will handle the fee charge internally
            contracts[i].chargeManagementFee(managementFee, id, price, time);
        }
    }

    /**
     * @notice Distributes the funds among the fund stakeholders.
     * @dev This function calculates the distribution amounts for both GP and LP,
     *      taking carried interest into consideration. After the calculations,
     *      the distributions are processed accordingly. Only accounts with the
     *      FUND_ADMIN role can call this function.
     * @param amount The total amount to distribute.
     * @param distributionType The type of distribution.
     * @param time The timestamp when the distribution is made.
     */
    function distribute(uint256 amount, string calldata distributionType, uint256 time) public onlyRole(FUND_ADMIN) {
        // Record the distribution and get the distribution ID
        uint32 distId = addDistribution(amount, distributionType, time);

        // Calculate the new total distribution amount
        uint256 newTotal = totalDistribution + amount;
        setTotalDistribution(newTotal);

        uint256 carry = carriedInterest;

        // Calculate the distribution amount, capital paid, and interest paid
        (uint256 distributionAmount, uint256 capitalPaid, uint256 interestPaid) =
            addOutflow(amount, scale, getPrefRate(), time, getCompoundingInterval());

        uint256 lpDist = capitalPaid + interestPaid;

        // If there's any interest paid, add it to GP's catchup
        if (interestPaid > 0) {
            addGpCatchup((interestPaid * carry) / 1000);
        }

        uint256 totalCatchup = getGpCatchup();

        // If the distribution amount is less than or equal to total catchup, process the distributions
        if (distributionAmount <= totalCatchup) {
            if (lpDist > 0) {
                processDistribution(lpFundToken, distributionType, time, distId, lpDist, scale);
                addLpReturn(lpDist);
            }

            if (distributionAmount > 0) {
                processDistribution(gpFundToken, distributionType, time, distId, distributionAmount, scale);
                addGpReturn(distributionAmount);
                setGpCatchup(totalCatchup - distributionAmount);
            }
            return;
        }

        uint256 gpDist = totalCatchup;

        // Adjust the distribution amount and GP catchup
        if (totalCatchup > 0) {
            setGpCatchup(0);
            distributionAmount -= totalCatchup;
        }

        // Calculate GP's and LP's distribution amounts
        uint256 gpSplit = (distributionAmount * carry) / 1000;
        gpDist += gpSplit;
        lpDist += distributionAmount - gpSplit;

        // Process the distributions and update returns
        if (gpDist > 0) {
            processDistribution(gpFundToken, distributionType, time, distId, gpDist, scale);
            addGpReturn(gpDist);
        }

        if (lpDist > 0) {
            processDistribution(lpFundToken, distributionType, time, distId, lpDist, scale);
            addLpReturn(lpDist);
        }
    }

    /// @notice Redeem tokens for the specified account
    /// @dev Adds a redemption request after checking if the account is compliant
    /// @param account The address of the account requesting the redemption
    /// @param amount The amount of tokens to be redeemed
    /// @param time The timestamp when the redemption request was made
    function redeem(address account, uint256 amount, uint256 time) public {
        // Ensure user can commit
        require(registry.isCompliant(account), "Account is not compliant");

        // Add redemption request
        addRedemption(account, amount, time);
    }

    // @inheritdoc
    function cancelRedemption(address account, uint256 time) public override {
        require(msg.sender == account, "Only the account owner can cancel redemption");
        super.cancelRedemption(account, time);
    }

    // @inheritdoc
    function addRedemption(address account, uint256 amount, uint256 time) public override onlyRole(FUND_ADMIN) {
        super.addRedemption(account, amount, time);
    }

    // @inheritdoc
    function approveRedemption(address account, uint256 time) public override onlyRole(FUND_ADMIN) {
        super.approveRedemption(account, time);

        // burnFrom checks caller has TOKEN_ADMIN role
        lpFundToken.burnFrom(account, redemptions[account].amount);
    }

    // @inheritdoc
    function rejectRedemption(address account, uint256 time) public override onlyRole(FUND_ADMIN) {
        super.rejectRedemption(account, time);
    }
}
