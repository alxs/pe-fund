// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/fund/Fund.sol";
import "../src/fund/CommitmentManager.sol";
import "../src/compliance/ComplianceRegistry.sol";

contract FundDemoScript is Script {
    Fund fund;
    ComplianceRegistry registry;
    address[] accounts = new address[](2);

    function run() public {
        // Setup
        address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        address lp1 = vm.addr(1);
        address lp2 = vm.addr(2);
        address fundAdmin = vm.addr(3);
        address kycAdmin = vm.addr(4);
        address amlAdmin = vm.addr(5);
        accounts[0] = lp1;
        accounts[1] = lp2;

        registry = new ComplianceRegistry(kycAdmin, amlAdmin);
        uint32 expiry = uint32(block.timestamp + 30 days);
        vm.startPrank(kycAdmin);
        registry.setKycStatus(lp1, expiry, ComplianceRegistry.Status.Compliant);
        registry.setKycStatus(lp2, expiry, ComplianceRegistry.Status.Compliant);
        vm.stopPrank();
        vm.startPrank(amlAdmin);
        registry.setAmlStatus(lp1, expiry, ComplianceRegistry.Status.Compliant);
        registry.setAmlStatus(lp2, expiry, ComplianceRegistry.Status.Compliant);
        vm.stopPrank();

        vm.startPrank(fundAdmin);
        // Step 1: Deploy fund
        fund = new Fund({
            name_: "Demo Fund",
            registryAddress_: address(registry),
            usdc_: address(usdc),
            initialClosing_: uint32(block.timestamp + 1 days),
            finalClosing_: uint32(block.timestamp + 30 days),
            endDate_: uint32(block.timestamp + 60 days),
            commitmentDate_: uint32(block.timestamp + 15 days),
            blockSize_: 10000,
            scale_: 8,
            price_: 100,
            prefRate_: 8,
            compoundingInterval_: InterestPayments.CompoundingPeriod.ANNUAL_COMPOUNDING,
            gpClawback_: 20,
            carriedInterest_: 20,
            managementFee_: 2
        });
        console.log("Step 1: Fund deployed successfully");
        showFundDetails();

        // Step 2: LP1 commits
        fund.addLpCommit(lp1, 20000000);
        console.log("Step 2: LP1 commitment added successfully");
        showFundDetails();

        // Step 3: LP2 commits
        fund.addLpCommit(lp2, 40000000);
        console.log("Step 3: LP2 commitment added successfully");
        showFundDetails();

        // Step 4: Approve commits
        vm.warp(block.timestamp + 1 days);
        fund.approveCommits(accounts);
        console.log("Step 4: LP1 and LP2 commits approved");
        showFundDetails();

        // Step 5: Admin calls capital
        vm.warp(block.timestamp + 1 days);
        uint16 callId = fund.capitalCall(10000000, "invest A");
        console.log("Step 6: Capital called");
        showFundDetails();

        // Step 6: Admin confirms capital call for LP1
        fund.capitalCallDone(callId, lp1, 100);
        console.log("Step 7: Capital call confirmed for LP1");
        showFundDetails();

        // Step 7: Admin confirms capital call for LP2
        fund.capitalCallDone(callId, lp2, 100);
        console.log("Step 8: Capital call confirmed for LP2");
        showFundDetails();
    }

    function showFundDetails() private view {
        console.log("--------------------------------------------------------");
        console.log("%s Details", fund.name());
        console.log("--------------------------------------------------------");

        // Print general fund details
        uint256 fundSize = fund.blockSize();
        uint256 fundPrice = fund.price();
        uint256 totalCommitted = fund.totalCommitted();
        uint256 totalCommittedGp = fund.totalCommittedGp();
        uint256 totalCommittedLp = fund.totalCommittedLp();
        uint256 totalCalled = fund.totalCalled();
        console.log("Block Size             | %d", fundSize);
        console.log("Price                  | %d", fundPrice);
        console.log("Total Committed        | %d", totalCommitted);
        console.log(unicode" ├─ Committed by GPs   | %d", totalCommittedGp);
        console.log(unicode" └- Committed by LPs   | %d", totalCommittedLp);
        console.log("Total Called           | %d", totalCalled);

        console.log("--------------------------------------------------------");
        console.log("Account Details");
        console.log("--------------------------------------------------------");

        for (uint256 i = 0; i < accounts.length; i++) {
            console.log("Account: %s (LP%s)", accounts[i], i + 1);

            // Print account commitments
            (uint256 amount, Fund.CommitState status) = fund.lpCommitments(accounts[i]);
            console.log("   Commitment: %d, Status: %s", amount, commitStateToString(uint8(status)));

            // Print LP commit token balance
            uint256 lpCommitAmount = fund.lpCommitToken().balanceOf(accounts[i]);
            console.log("   LP Commit Tokens : %d", lpCommitAmount);

            // Print GP commit token balance
            uint256 gpCommitAmount = fund.gpCommitToken().balanceOf(accounts[i]);
            console.log("   GP Commit Tokens : %d", gpCommitAmount);

            // Print LP Fund Token balance
            uint256 lpFundAmount = fund.lpFundToken().balanceOf(accounts[i]);
            console.log("   LP Fund Tokens   : %d", lpFundAmount);

            // Print GP Fund Token balance
            uint256 gpFundAmount = fund.gpFundToken().balanceOf(accounts[i]);
            console.log("   GP Fund Tokens   : %d", gpFundAmount);

            console.log("--------------------------------------------------------");
        }
        console.log("\n\n");
    }

    function commitStateToString(uint8 state) private pure returns (string memory) {
        if (state == 0) return "COMMIT_NONE";
        if (state == 1) return "COMMIT_PENDING";
        if (state == 2) return "COMMIT_APPROVED";
        if (state == 3) return "COMMIT_CANCELLED";
        if (state == 4) return "COMMIT_REJECTED";
        if (state == 5) return "COMMIT_BLOCKED";
        return "Unknown";
    }
}
