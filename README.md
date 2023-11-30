# Solidity Contracts for Private Equity Fund

## Overview
This repository contains a suite of Solidity smart contracts implementing core functionality for a private equity fund based on the [Whole of Fund Model Limited Partnership Agreement](https://ilpa.org/model-lpa/) provided by the Institutional Limited Partners Association (ILPA).

The contracts are intended to digitally represent key aspects of fund operations including compliance, capital calls, commitments, distributions, tokenization of fund interests, and general partnership management on-chain.

## Key Concepts

### Commitments 
The [`CommitmentManager`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/CommitmentManager.sol) contract handles Limited Partners' (LPs) capital commitments to the fund. This implements the capital commitment mechanics described in Section 4.2 of the model LPA, including:
- Enabling LPs to make commitments to the fund by issuing LP Commitment Tokens representing each LP's committed capital amount (Section 4.2.1)
- Tracking the status of each commitment as PENDING, APPROVED, CANCELLED, etc. (Section 4.2.3)  
- Allowing the GP to approve outstanding commitments once the fund reaches its initial closing (Section 4.2.4)
- Permitting LPs to cancel their commitments prior to approval (Section 4.2.5)

### Capital Calls
The [`CapitalCallsManager`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/CapitalCallsManager.sol) contract facilitates capital calls by the General Partner (GP) to draw committed funds from LPs. This implements the capital call process defined in Section 4.3 of the model LPA, including:
- Issuing capital calls approved by the GP and notifying LPs (Section 4.3.1)  
- Calculating each LP's share of a capital call amount based on commitments (Section 4.3.2)
- Allowing LPs to confirm funding to fulfill calls by their due date (Section 4.3.3)

### Distributions
Distributions to LPs and carried interest distributions to the GP are handled by the core [`Fund`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/Fund.sol) contract based on provisions in Section 6 of the model LPA, including:
- Calculating LP and GP allocation percentages (Section 6.1)
- Distributing proceeds among partners (Section 6.2)

### Redemptions
The redemption process for Limited Partners (LPs) as described in Section 5 of the model LPA is implemented in the [`RedemptionManager`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/RedemptionManager.sol) contract. The contract manages various states of the redemption workflow and maintains a record of all redemption activities. It allows LPs to initiate redemptions of their fund tokens in exchange for a proportionate share of the fund's net assets, as described in Section 5 of the model LPA. 

### Interest Payments  
The [`InterestPayments`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/InterestPayments.sol) contract manages the calculation and distribution of interest payments to LPs per the terms in Section 6.2 of the model LPA. It supports different compounding periods (e.g. annual or quarterly) and calculates interest based on each LP's share of the fund's net asset value and investment performance. The contract also tracks all interest entries, including timestamp, compounded capital amount, daily interest rate, and cumulative cash flows to facilitate transparent and accurate interest distributions aligned with fund returns.

### Compliance
The [`ComplianceRegistry`](https://github.com/alxs/solidity-contracts/blob/master/src/compliance/ComplianceRegistry.sol) contract manages the Know Your Customer (KYC) and Anti-Money Laundering (AML) verification status of fund participants as discussed in Section 3.4. It provides functionality to track and update the compliance status of all addresses to ensure only regulations-compliant entities interface with the fund.

## Key Contracts

The main smart contracts are:

- `Fund.sol` - Core fund management
- `ComplianceRegistry.sol` - KYC/AML verification  
- `InterestPayments.sol` - Interest calculations
- `CommitmentManager.sol` - LP commitments
- `RedemptionManager.sol` - Redemption requests

Additional supporting contracts are also included.

## Usage

The contracts are designed to be deployed and initialized programmatically.

Interactions would primarily consist of:
- Making/increasing commitments
- Responding to capital calls
- Claiming distributions
- Initiating redemptions
The General Partner would manage fund operations like issuing capital calls, distributions, etc.

## Testing
The `test` directory contains Foundry [tests](https://github.com/alxs/solidity-contracts/blob/master/test/Fund.t.sol) for the fund contract.
In order to run them, follow the setup instructions below and then run `forge test`.
A [script](https://github.com/alxs/pe-fund/blob/master/script/Fund.s.sol) demoing the functionality of the project is available as well.

## Installation and Setup
This project was developed using Foundry.
If you would like to set it up on your machine, follow the [installation](https://book.getfoundry.sh/getting-started/installation) instructions in the Foundry Book, and then the instructions for [working on an existing project](https://book.getfoundry.sh/projects/working-on-an-existing-project).

## License
The contracts are provided for reference purposes only. If you would like to use them, commercially or not, please reach out or open an issue.
