// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../interfaces/IComplianceRegistry.sol";
import "../interfaces/ISecurityToken.sol";
import "../security_token/SecurityToken.sol";
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
    ERC20Pausable,
    AccessControl,
    Expenses,
    CapitalCalls,
    Distributions,
    Fees,
    Commitments,
    Deployments,
    Redemptions,
    InterestPayments
{
    bytes32 public constant FUND_ADMIN = keccak256("FUND_ADMIN");
    bytes32 public constant TOKEN_ADMIN = keccak256("TOKEN_ADMIN");

    IComplianceRegistry public registry;
    ISecurityToken public gpCommitToken;
    ISecurityToken public lpCommitToken;
    ISecurityToken public gpFundToken;
    ISecurityToken public lpFundToken;

    uint256 public size;
    uint256 public initialClosing;
    uint256 public finalClosing;
    uint256 public endDate;
    uint256 public gpClawbackPerc;
    uint256 public mgtFee;

    uint256 public commitmentDate;
    uint256 public deploymentStart;
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
        uint256 blockSize_
    ) {
        registry = IComplianceRegistry(registryAddress_);
        initialClosing = initialClosing_;
        finalClosing = finalClosing_;
        endDate = endDate_;
        commitmentDate = commitmentDate_;
        deploymentStart = deploymentStart_;
        blockSize = blockSize_;

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
     * @notice Sets the deployment start time of the fund.
     * @dev Can only be called by an account with the FUND_ADMIN role.
     * @param _deploymentStart The new deployment start time.
     */
    function setDeploymentStart(uint256 _deploymentStart) public onlyRole(FUND_ADMIN) {
        deploymentStart = _deploymentStart;
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
     * @param gpFundToken The address of the GP fund token.
     * @param lpFundToken The address of the LP fund token.
     */
    function capitalCall(
        uint256 amount,
        string memory drawdownType,
        uint256 time,
        address gpFundToken,
        address lpFundToken
    ) public onlyRole(FUND_ADMIN) {
        // Check if there is enough committed capital
        uint256 totalCommitted = totalCommittedLp + totalCommittedGp;
        uint256 left = totalCommitted - totalCalled;
        require(left >= amount, "FundError: Insufficient Commits");

        // Record the capital call
        uint256 callId = addCapitalCall(amount, drawdownType, time, gpFundToken, lpFundToken);

        uint8 scale = decimals();
        uint256 scaledAmount = amount * scale;

        require(scaledAmount / totalCommitted > 0, "FundError: Scale Overflow");
        uint256 scaledShare = scaledAmount / totalCommitted;

        // Calculate and record the capital call for each GP
        for (uint256 i = 0; i < gpCommitments.length; i++) {
            uint256 ss = scaledShare * gpCommitments[i].amount;
            require(ss / scale > 0, "FundError: Scale Overflow");
            uint256 share = ss / scale;
            require(share != 0, "FundError: Invalid Share");

            accountCapitalCalls[callId].push(gpCommitments[i].address, share, AccountType.Gp);
        }

        // And for each LP
        for (uint256 i = 0; i < lpCommitments.length; i++) {
            uint256 ss = scaledShare * lpCommitments[i].amount;
            require(ss / scale > 0, "FundError: Scale Overflow");
            uint256 share = ss / scale;
            require(share != 0, "FundError: Invalid Share");

            accountCapitalCalls[callId].add(lpCommitments[i].address, share, AccountType.Lp);
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
        for (uint256 i = 0; i < contracts.length; i++) {
            // Each contract will handle the fee charge internally
            contracts[i].chargeManagementFee(time, id, managementFee, price);
        }
    }

    /**
     * @notice Distributes the funds among the fund stakeholders.
     * @dev This function calculates the distribution amounts for both GP and LP,
     *      taking carried interest into consideration. After the calculations,
     *      the distributions are processed accordingly. Only accounts with the
     *      FUND_ADMIN role can call this function.
     * @param amount The total amount to distribute.
     * @param distribution_type The type of distribution.
     * @param time The timestamp when the distribution is made.
     * @param gpFundToken The GP fund token contract.
     * @param lpFundToken The LP fund token contract.
     */
    function distribute(
        uint256 amount,
        string memory distribution_type,
        uint256 time,
        ISecurityToken gpFundToken,
        ISecurityToken lpFundToken
    ) public onlyRole(FUND_ADMIN) {
        // Record the distribution and get the distribution ID
        uint256 dist_id = addDistribution(amount, distribution_type, time);

        // Calculate the new total distribution amount
        uint256 new_total = totalDistribution + amount;
        setTotalDistribution(new_total);

        uint256 scale = decimals();
        uint256 carry = carriedInterest;

        // Calculate the distribution amount, capital paid, and interest paid
        (uint256 distribution_amount, uint256 capital_paid, uint256 interest_paid) =
            addOutflow(amount, scale, getPrefRate(), time, getCompoundingInterval());

        uint256 lp_dist = capital_paid + interest_paid;

        // If there's any interest paid, add it to GP's catchup
        if (interest_paid > 0) {
            addGpCatchup((interest_paid * carry) / 1000);
        }

        uint256 total_catchup = getGpCatchup();

        // If the distribution amount is less than or equal to total catchup, process the distributions
        if (distribution_amount <= total_catchup) {
            if (lp_dist > 0) {
                processDistribution(lpFundToken, distribution_type, time, dist_id, lp_dist, scale);
                addLpReturn(lp_dist);
            }

            if (distribution_amount > 0) {
                processDistribution(gpFundToken, distribution_type, time, dist_id, distribution_amount, scale);
                addGpReturn(distribution_amount);
                setGpCatchup(total_catchup - distribution_amount);
            }
            return;
        }

        uint256 gp_dist = total_catchup;

        // Adjust the distribution amount and GP catchup
        if (total_catchup > 0) {
            setGpCatchup(0);
            distribution_amount -= total_catchup;
        }

        // Calculate GP's and LP's distribution amounts
        uint256 gp_split = (distribution_amount * carry) / 1000;
        gp_dist += gp_split;
        lp_dist += distribution_amount - gp_split;

        // Process the distributions and update returns
        if (gp_dist > 0) {
            processDistribution(gpFundToken, distribution_type, time, dist_id, gp_dist, scale);
            addGpReturn(gp_dist);
        }

        if (lp_dist > 0) {
            processDistribution(lpFundToken, distribution_type, time, dist_id, lp_dist, scale);
            addLpReturn(lp_dist);
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

    /**
     * @dev Pauses all token transfers.
     * See {Pausable-_pause}.
     * Only callable by FUND_ADMIN role.
     */

    function pause() public onlyRole(TOKEN_ADMIN) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     * See {Pausable-_unpause}.
     * Only callable by FUND_ADMIN role.
     */
    function unpause() public onlyRole(TOKEN_ADMIN) {
        _unpause();
    }
}
