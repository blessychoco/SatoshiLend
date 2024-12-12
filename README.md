# Stacks Bitcoin-Backed Lending Platform

## Overview
This smart contract enables a decentralized lending platform built on Stacks, allowing users to create loans using Bitcoin as collateral via the Stacks blockchain.

## Features
- Peer-to-peer lending
- Bitcoin-backed collateralization
- Smart contract-based loan management
- Transparent loan creation and repayment
- Liquidation mechanism for defaulted loans

## Contract Functions

### `create-loan`
Create a new loan with specified parameters:
- `collateral-amount`: Amount of Bitcoin-backed collateral
- `loan-amount`: Requested loan amount
- `interest-rate`: Percentage interest rate
- `loan-duration`: Number of blocks until loan is due

### `repay-loan`
Repay an existing loan, calculating total amount with interest:
- Marks loan as inactive upon full repayment
- Calculates and applies interest

### `liquidate-loan`
Liquidate a loan that has passed its duration:
- Checks if loan is past due
- Marks loan as inactive

## Error Handling
The contract includes comprehensive error handling:
- `ERR-INSUFFICIENT-FUNDS`: Invalid loan amounts
- `ERR-UNAUTHORIZED`: Unauthorized loan actions
- `ERR-LOAN-NOT-FOUND`: Non-existent loan
- `ERR-LOAN-REPAYMENT-FAILED`: Repayment issues
- `ERR-LIQUIDATION-NOT-ALLOWED`: Premature liquidation attempts

## Technical Details
- Implemented in Clarity smart contract language
- Uses Stacks blockchain for execution
- Supports complex loan lifecycle management

## Security Considerations
- Loans are tracked via immutable mappings
- Borrower-specific loan tracking
- Block-height based loan duration

## Deployment Requirements
- Stacks blockchain environment
- Compatible Stacks wallet
- Sufficient STX tokens for transaction fees

## Future Improvements
- Multi-token collateral support
- More granular interest calculations
- Enhanced liquidation mechanisms

## Getting Started
1. Deploy contract to Stacks blockchain
2. Connect compatible wallet
3. Create loans using Bitcoin collateral