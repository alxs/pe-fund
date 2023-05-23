// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/fund/Fund.sol";
import "../src/compliance/ComplianceRegistry.sol";

contract FundTest is Test {
    Fund fund;
    ComplianceRegistry registry;
    IERC20 usdc;

    address owner;
    address kycAdmin;
    address amlAdmin;
    address compliantAccount;

    function setUp() external {
        // generate addresses
        owner = vm.addr(1);
        kycAdmin = vm.addr(2);
        amlAdmin = vm.addr(3);
        compliantAccount = vm.addr(4);

        // deploy registry and make compliantAccount compliant
        registry = new ComplianceRegistry(kycAdmin, amlAdmin);
        vm.prank(kycAdmin);
        registry.setKycStatus(compliantAccount, uint32(block.timestamp + 30 days), ComplianceRegistry.Status.Compliant);
        vm.prank(amlAdmin);
        registry.setAmlStatus(compliantAccount, uint32(block.timestamp + 30 days), ComplianceRegistry.Status.Compliant);

        // deploy fund
        fund = new Fund({
            name_: "Test Fund",
            registryAddress_: address(registry),
            initialClosing_: uint32(block.timestamp + 1 days),
            finalClosing_: uint32(block.timestamp + 30 days),
            endDate_: uint32(block.timestamp + 60 days),
            commitmentDate_: uint32(block.timestamp + 15 days),
            deploymentStart_: uint32(block.timestamp),
            blockSize_: 10000, // block size
            scale_: 1, // scale
            price_: 100, // price
            prefRate_: 5, // preferred rate
            compoundingInterval_: 1, // compounding interval
            gpClawback_: 20, // gp clawback
            carriedInterest_: 20, // carried interest
            managementFee_: 2 // management fee
        });

        // fund._initTokens(usdc);
        // @todo
    }

    function test_commitment() public {
        // Test that a user can successfully commit funds

        // For this test, I assume the following parameters:
        // - account: address(0x1234567890123456789012345678901234567890)
        // - amount: 1000 * fund.blockSize() // example blockSize is 1000
        // - time: 1635772800 (2022-11-01 18:00:00)

        // Get initial total committed LP tokens
        uint256 initialTotal = fund.totalCommittedLp();

        // Call the commit function with the specified parameters
        fund.commit(address(0x1234567890123456789012345678901234567890), 1000 * fund.blockSize(), 1635772800);

        // Check the new total committed LP tokens
        uint256 newTotal = fund.totalCommittedLp();

        // Assert the new total should be initial total + amount (1000 * fund.blockSize())
        assertEq(newTotal, initialTotal + (1000 * fund.blockSize()));
    }

    function testFail_commitment_notCompliant() public {
        // Test that a not compliant user cannot commit

        // For this test, I assume the following parameters:
        // - account: address(0x1234567890123456789012345678901234567890)
        // - amount: 1000 * fund.blockSize() // example blockSize is 1000
        // - time: 1635772800 (2022-11-01 18:00:00)

        // Make the account not compliant (you should implement this function in the IComplianceRegistry contract)
        vm.prank(kycAdmin);
        registry.setKycStatus(
            address(0x1234567890123456789012345678901234567890),
            block.timestamp + 1,
            ComplianceRegistry.Status.NonCompliant
        );

        // Call the commit function with the specified parameters, should fail
        fund.commit(address(0x1234567890123456789012345678901234567890), 1000 * fund.blockSize(), 1635772800);
    }

    function test_cancelCommit() public {
        // Test that a user can successfully cancel their commitment

        // First, make a successful commit
        uint256 blockSize = fund.blockSize();
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * blockSize;
        uint256 time = 1635772800;
        fund.commit(account, amount, time);

        // Check the user's commitment exists
        (uint256 initialCommitAmount,,) = fund.lpCommitments(account);
        assertEq(initialCommitAmount, amount);

        // Call the cancelCommit function with the specified parameters
        fund.cancelCommit(account, time);

        // Check the user's commitment is removed
        (uint256 newCommitAmount,,) = fund.lpCommitments(account);
        assertEq(newCommitAmount, 0);
    }

    function test_issueGpCommit() public {
        // Test that a GP commit can be issued and the correct token is minted

        // For this test, I assume the following parameters:
        // - account: address(0x123456789012345678901234567890123456>)
        // - amount: 1000 * fund.blockSize() // example blockSize is 1000
        // - time: 1635772800 (2022-11-01 18:00:00)

        uint256 amount = 1000 * fund.blockSize();
        uint256 time = 1635772800;

        // Get the initial GP commit token balance
        uint256 initialBalance = fund.gpCommitToken().balanceOf(compliantAccount);

        // Call the issueGpCommit function with the specified parameters
        fund.issueGpCommit(compliantAccount, amount, time);

        // Obtain the GP commit token balance after issuance
        uint256 newBalance = fund.gpCommitToken().balanceOf(compliantAccount);

        // Assert that the new balance has increased by the amount
        assertEq(newBalance, initialBalance + amount);
    }

    function test_capitalCall() public {
        // Test that a capital call can be correctly executed

        // For this test, I assume the following parameters:
        // - amount: 9000
        // - drawdownType: "Example Drawdown"
        // - time: 1635772800 (2022-11-01 18:00:00)

        uint256 amount = 9000;
        string memory drawdownType = "Example Drawdown";
        uint32 time = 1635772800;

        // Call the capitalCall function with the specified parameters
        uint256 callId = fund.capitalCall(amount, drawdownType, time);

        // Check the capital call data
        (uint256 amount_, string memory drawdownType_, uint256 time_) = fund.capitalCalls(callId);

        // Assert that the data matches the expected values
        assertEq(amount_, amount);
        assertEq(drawdownType_, drawdownType);
        assertEq(time_, time);
    }

    function test_chargeManagementFee() public {
        // @todo
        // Test that a management fee can be correctly charged to all LP contracts
        // Use mock data and contracts to simulate real funds(use Mocks).

        // Capture the current timestamp
        // uint256 time = block.timestamp;

        // Call the chargeManagementFee function
        // fund.chargeManagementFee();

        // Check fee charged in all LP contracts, use mocked fund contracts and getFeeRequest function (to be implemented in the contract)
        // Verify that the management fee is correctly applied to all LP contracts (use mocks).
    }

    function test_distribute() public {
        // Test that funds can be correctly distributed among stakeholders

        // For this test, I assume the following parameters:
        // - amount: 10000
        // - distributionType: "Example Distribution"
        // - time: 1635772800 (2022-11-01 18:00:00)

        uint256 amount = 10000;
        string memory distributionType = "Example Distribution";
        uint32 time = 1635772800;

        // Capture initial distribution values
        uint256 initialLpReturn = fund.getLpReturn();
        uint256 initialGpReturn = fund.getGpReturn();

        // Call the distribute function with the specified parameters
        fund.distribute(amount, distributionType, time);

        // Check updated distribution values
        uint256 newLpReturn = fund.getLpReturn();
        uint256 newGpReturn = fund.getGpReturn();

        // Assert that the distributions have been updated (exact amounts depend on the logic in the distribute function)
        assert(newLpReturn > initialLpReturn);
        assert(newGpReturn > initialGpReturn);
    }

    function test_redeem() public {
        // Test that a user can successfully redeem tokens

        // For this test, I assume the following parameters:
        // - account: address(0x1234567890123456789012345678901234567890)
        // - amount: 1000 *fund.blockSize() // example blockSize is 1000
        // - time: 1635772800 (2022-11-01 18:00:00)

        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        uint256 time = 1635772800;

        // Get the initial redeemable tokens
        uint256 initialRedeemableTokens = fund.lpFundToken().balanceOf(account);

        // Call the redeem function with the specified parameters
        fund.redeem(account, amount, time);

        // Check the new redeemable tokens
        uint256 newRedeemableTokens = fund.lpFundToken().balanceOf(account);

        // Assert the new redeemable tokens is reduced by the amount
        assertEq(newRedeemableTokens, initialRedeemableTokens - amount);
    }

    function test_cancelRedemption_owner() public {
        // Test that only the account owner can cancel a redemption

        // First, make a successful redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        uint256 time = 1635772800;
        fund.redeem(account, amount, time);

        // Check the user's redemption request exists
        (, uint256 initialAmount,,) = fund.redemptions(account);
        assertEq(initialAmount, amount);

        // Call the cancelRedemption function with the specified parameters
        // Assume msg.sender is the account owner
        fund.cancelRedemption(account, time);

        // Check the user's redemption request is removed
        (, uint256 newAmount,,) = fund.redemptions(account);
        assertEq(newAmount, 0);
    }

    function testFail_cancelRedemption_notOwner() public {
        // Test that a non-owner cannot cancel a redemption

        // First, make a successful redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        uint256 time = 1635772800;
        vm.startPrank(compliantAccount);
        fund.redeem(account, amount, time);

        // Call the cancelRedemption function with the specified parameters
        // Assume msg.sender is not the account owner
        // You might want to use a custom modifier and a function argument
        // to simulate the msg.sender being different from the account owner
        fund.cancelRedemption(account, time);
    }

    function test_approveRedemption() public {
        // Test that a redemption can be correctly approved

        // First, add a redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        uint256 time = 1635772800;
        fund.redeem(account, amount, time);

        // Call the approveRedemption function with the specified parameters
        fund.approveRedemption(account, time);

        // Check that the lpFundToken is burned
        assertEq(fund.lpFundToken().totalSupply(), 0);
    }

    function test_rejectRedemption() public {
        // Test that a redemption can be correctly rejected

        // First, make a successful redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        uint256 time = 1635772800;
        fund.redeem(account, amount, time);

        // Call the rejectRedemption function with the specified parameters
        fund.rejectRedemption(account, time);

        // Check the user's redemption request status
        (,,, Fund.RedemptionStatus redemptionStatus) = fund.redemptions(account);
        // @todo why are these struct members not exposed, but the ones from registry are?
        assertEq(uint256(redemptionStatus), 3);
    }
}
