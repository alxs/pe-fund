# Solidity Contracts for Private Equity Fund

## Overview
This repository contains a suite of Solidity contracts designed to emulate the structure of a private equity fund, in line with the [model Limited Partnership Agreements](https://ilpa.org/model-lpa/) (LPAs) provided by the Institutional Limited Partners Association (ILPA).
The contracts implement various aspects of fund management, including compliance, capital calls, commitments, fund operations, and tokenization of fund interests.

## Key Concepts

### Compliance
The project includes a [`ComplianceRegistry`](https://github.com/alxs/solidity-contracts/blob/master/src/compliance/ComplianceRegistry.sol) contract, which manages the Know Your Customer (KYC) and Anti-Money Laundering (AML) compliance status of fund participants.
This contract ensures that the fund only deals with entities compliant with regulatory requirements by tracking and updating the verification status of addresses.
The compliance status is time-bound, expiring after a set duration.

### Commitments
The ability for Limited Partners (LPs) to make commitments to the fund, a key feature of private equity funds, is implemented in the [`CommitmentManager`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/CommitmentManager.sol) contract.
This contract enables LPs to make, increase, and decrease their commitments, representing a promise to provide a specified amount of capital when called upon by the fund.

### Capital Calls
When the fund needs to draw on the commitments made by LPs, it issues a capital call, implemented in the [`CapitalCallsManager`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/CapitalCallsManager.sol) contract.
This contract allows the fund to issue capital calls and enables LPs to fulfill them, managing the process of drawing down committed capital.

### Redemptions
The [`RedemptionManager`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/RedemptionManager.sol) contract facilitates the redemption process for Limited Partners (LPs).
It allows LPs to request the redemption of their fund tokens in exchange for a proportionate share of the fund's assets.
The contract manages various states of the redemption process, including pending, approved, cancelled, rejected, and blocked redemptions.
It ensures that only valid redemption requests are processed and maintains a record of all redemption activities.

### Interest Payments
The [`InterestPayments`](https://github.com/alxs/solidity-contracts/blob/master/src/fund/InterestPayments.sol) contract manages the calculation and distribution of interest payments to LPs.
It supports different compounding periods, such as annual and quarterly, and calculates interest based on the LP's share of the fund's assets and the fund's performance.
The contract maintains a record of all interest entries, including timestamp, compounded capital amount, daily interest rate, and total cash flow.
This enables a transparent and accurate distribution of interest payments in line with the fund's performance.

## Testing
The `test` directory contains Solidity [tests](https://github.com/alxs/solidity-contracts/blob/master/test/Fund.t.sol) for the fund contract, ensuring the correctness and reliability of the fund's operations.
A [script](https://github.com/alxs/pe-fund/blob/master/script/Fund.s.sol) demoing the functionality of the project is available as well.

## Installation and Setup
This project was developed using Foundry.
If you want to set it up on your machine, follow the [installation](https://book.getfoundry.sh/getting-started/installation) instructions in the Foundry Book, and then the instructions for [working on an existing project](https://book.getfoundry.sh/projects/working-on-an-existing-project).

## License
Note that this project is not licensed. If you would like to use it, commercially or not, please reach out or open an issue.
