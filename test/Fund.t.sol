// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "ds-test/test.sol";
import "../src/fund/Fund.sol";

contract FundTest is DSTest {
    Fund fund;

    // Declare the ERC20 token contracts for the test
    ERC20 private btc;
    ERC20 private usdc;
    ERC20 private weth;

    function setUp() public {
        // Instantiate the ERC20 token contracts
        btc = new ERC20("BTC", "Bitcoin");
        usdc = new ERC20("USDC", "USD Coin");
        weth = new ERC20("WETH", "Wrapped ETH");

        // Create and configure the Fund contract with initial parameters
        fund = new Fund( // Example address for registryAddress and tokenAdmin
            address(0x1234567890123456789012345678901234567890),
        address(0x0987654321098765432109876543210987654321),
        1635765600, // example of initialClosing timestamp (2022-11-01 14:00:00)
        1640972400, // example of finalClosing timestamp (2022-12-31 23:00:00)
        1667334000, // example of endDate timestamp (2022-10-27 18:00:00)
        1653909600, // example of commitmentDate timestamp (2023-05-30 21:00:00)
        1651486800, // example of deploymentStart timestamp (2023-05-01 21:30:00)
        1000, // example of blockSize
        8, // example of scale
        10000, // example of price
        10, // example of prefRate
        2, // example of compoundingInterval
        20, // example of gpClawback
        20, // example of carriedInterest
        2  // example of managementFee
    );
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

    // function testFail_commitment_invalidSize() public {
    //     // Test that a user cannot commit an invalid size
    // }

    // function testFail_commitment_notCompliant() public {
    //     // Test that a not compliant user cannot commit
    // }

    // function test_cancelCommit() public {
    //     // Test that a user can successfully cancel their commitment
    // }

    // function test_issueGpCommit() public {
    //     // Test that a GP commit can be issued and the correct token is minted
    // }

    // function test_capitalCall() public {
    //     // Test that a capital call can be correctly executed
    // }

    // function testFail_capitalCall_insufficientCommits() public {
    //     // Test that a capital call cannot be executed if there are insufficient commits
    // }

    // function test_chargeManagementFee() public {
    //     // Test that a management fee can be correctly charged to all LP contracts
    // }

    // function test_distribute() public {
    //     // Test that funds can be correctly distributed among stakeholders
    // }

    // function test_redeem() public {
    //     // Test that a user can successfully redeem tokens
    // }

    // function test_cancelRedemption_owner() public {
    //     // Test that only the account owner can cancel a redemption
    // }

    // function testFail_cancelRedemption_notOwner() public {
    //     // Test that a non-owner cannot cancel a redemption
    // }

    // function test_approveRedemption() public {
    //     // Test that a redemption can be correctly approved
    // }

    // function test_rejectRedemption() public {
    //     // Test that a redemption can be correctly rejected
    // }
}
