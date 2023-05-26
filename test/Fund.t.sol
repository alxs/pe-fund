// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "forge-std/Test.sol";
import "../src/fund/Fund.sol";
import "../src/compliance/ComplianceRegistry.sol";

contract FundTest is Test {
    Fund fund;
    ComplianceRegistry registry;
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

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
            usdc_: address(usdc),
            initialClosing_: uint32(block.timestamp + 1 days),
            finalClosing_: uint32(block.timestamp + 30 days),
            endDate_: uint32(block.timestamp + 60 days),
            commitmentDate_: uint32(block.timestamp + 15 days),
            blockSize_: 10000, // block size
            scale_: 1, // scale
            price_: 100, // price
            prefRate_: 5, // preferred rate
            compoundingInterval_: InterestPayments.CompoundingPeriod.ANNUAL_COMPOUNDING, // compounding interval
            gpClawback_: 20, // gp clawback
            carriedInterest_: 20, // carried interest
            managementFee_: 2 // management fee
        });
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
        fund.addLpCommit(address(0x1234567890123456789012345678901234567890), 1000 * fund.blockSize());

        // Check the new total committed LP tokens
        uint256 newTotal = fund.totalCommittedLp();

        // Assert the new total should be initial total + amount (1000 * fund.blockSize())
        assertEq(newTotal, initialTotal + (1000 * fund.blockSize()));
    }

    function testFail_commit_notCompliant() public {
        // @todo
    }

    function testFail_addLpCommit_notCompliant() public {
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
        fund.addLpCommit(address(0x1234567890123456789012345678901234567890), 1000 * fund.blockSize());
    }

    function test_cancelCommit() public {
        // Test that a user can successfully cancel their commitment

        // First, make a successful commit
        uint256 blockSize = fund.blockSize();
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * blockSize;
        fund.addLpCommit(account, amount);

        // Check the user's commitment exists
        (uint256 initialCommitAmount,) = fund.lpCommitments(account);
        assertEq(initialCommitAmount, amount);

        // Call the cancelCommit function with the specified parameters
        fund.cancelCommit(account);

        // Check the user's commitment is removed
        (uint256 newCommitAmount,) = fund.lpCommitments(account);
        assertEq(newCommitAmount, 0);
    }

    function test_issueGpCommit() public {
        // Test that a GP commit can be issued and the correct token is minted

        // For this test, I assume the following parameters:
        // - account: address(0x123456789012345678901234567890123456>)
        // - amount: 1000 * fund.blockSize() // example blockSize is 1000
        // - time: 1635772800 (2022-11-01 18:00:00)

        uint256 amount = 1000 * fund.blockSize();

        // Get the initial GP commit token balance
        uint256 initialBalance = fund.gpCommitToken().balanceOf(compliantAccount);

        // Call the issueGpCommit function with the specified parameters
        fund.issueGpCommit(compliantAccount, amount);

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

        // Call the capitalCall function with the specified parameters
        uint16 callId = fund.capitalCall(amount, drawdownType);

        // Check the capital call data
        (uint256 amount_, string memory drawdownType_) = fund.capitalCalls(callId);

        // Assert that the data matches the expected values
        assertEq(amount_, amount);
        assertEq(drawdownType_, drawdownType);
    }

    function test_chargeManagementFee() public {
        // Test that a management fee can be correctly charged to all LP contracts
        // Use mock data and contracts to simulate real funds(use Mocks).

        // Call the chargeManagementFee function
        fund.chargeManagementFee();

        // Check fee charged in all LP contracts, use mocked fund contracts and getFeeRequest function (to be implemented in the contract)
        // Verify that the management fee is correctly applied to all LP contracts (use mocks).
        // @todo
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
        uint256 initialLpReturn = fund.lpReturn();
        uint256 initialGpReturn = fund.gpReturn();

        // Call the distribute function with the specified parameters
        fund.distribute(amount, distributionType, time);

        // Check updated distribution values
        uint256 newLpReturn = fund.lpReturn();
        uint256 newGpReturn = fund.gpReturn();

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

        // Get the initial redeemable tokens
        uint256 initialRedeemableTokens = fund.lpFundToken().balanceOf(account);

        // Call the redeem function with the specified parameters
        fund.addRedemption(account, amount);

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
        fund.addRedemption(account, amount);

        // Check the user's redemption request exists
        (, uint256 initialAmount,) = fund.redemptions(account);
        assertEq(initialAmount, amount);

        // Call the cancelRedemption function with the specified parameters
        // Assume msg.sender is the account owner
        fund.cancelRedemption(account);

        // Check the user's redemption request is removed
        (, uint256 newAmount,) = fund.redemptions(account);
        assertEq(newAmount, 0);
    }

    function testFail_cancelRedemption_notOwner() public {
        // Test that a non-owner cannot cancel a redemption

        // First, make a successful redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        vm.startPrank(compliantAccount);
        fund.addRedemption(account, amount);

        // Call the cancelRedemption function with the specified parameters
        // Assume msg.sender is not the account owner
        // You might want to use a custom modifier and a function argument
        // to simulate the msg.sender being different from the account owner
        fund.cancelRedemption(account);
    }

    function test_approveRedemption() public {
        // Test that a redemption can be correctly approved

        // First, add a redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        fund.addRedemption(account, amount);

        // Call the approveRedemption function with the specified parameters
        fund.approveRedemption(account);

        // Check that the lpFundToken is burned
        assertEq(fund.lpFundToken().totalSupply(), 0);
    }

    function test_rejectRedemption() public {
        // Test that a redemption can be correctly rejected

        // First, make a successful redemption
        address account = address(0x1234567890123456789012345678901234567890);
        uint256 amount = 1000 * fund.blockSize();
        fund.addRedemption(account, amount);

        // Call the rejectRedemption function with the specified parameters
        fund.rejectRedemption(account);

        // Check the user's redemption request status
        (,, Fund.RedemptionStatus redemptionStatus) = fund.redemptions(account);
        // For some reason these struct members are not exposed, but the ones from registry are
        assertEq(uint256(redemptionStatus), 3);
    }
}
