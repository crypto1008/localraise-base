# LocalRaise 🚀

**Micro-investment platform for local businesses on Base Mainnet.**

Fund local businesses. Earn real returns. No banks needed.

## Contract Address
`0x93D50E14d2D269b594997677bEa46B766DD9A7ED`

## View on Basescan
https://basescan.org/address/0x93D50E14d2D269b594997677bEa46B766DD9A7ED

## Live Frontend
https://crypto1008.github.io/localraise-base

## The Problem
500 million small businesses globally need funding.
Banks reject 80% of them.
Moneylenders charge 40%+ interest.
Friends want to help but need real returns.

## The Solution
LocalRaise lets communities micro-invest in local businesses on Base.
Businesses get funded instantly with zero bank paperwork.
Investors earn real returns, tracked transparently onchain.
If the goal isn't reached — everyone is automatically refunded.

## Return Models
- **Revenue Share** — Business shares % of monthly profit with investors
- **Fixed Return** — Business repays principal + agreed fixed interest

## Business Categories
- 🍵 Food & Beverage
- 🛒 Retail & Local Shop
- 🚗 Transport & Logistics

## How It Works
1. Business creates a funding campaign with a goal, return offer, and deadline
2. Community members invest any amount of ETH (min 0.001 ETH)
3. Goal reached → Business receives funds instantly (minus 1.5% platform fee)
4. Business sends monthly payments back through the contract
5. All investors receive proportional returns automatically

## V2 Features
- 🆘 **Default Protection** — Auto-blacklist after 60 days without payment
- ⭐ **Investor Reviews** — 1–5 star ratings stored permanently onchain
- 💬 **Campaign Updates** — Business posts monthly progress for investors
- 🔄 **Early Exit Marketplace** — Investors can sell positions to others
- 🎯 **Milestone Tracking** — Funds released in stages, not all at once
- 💰 **Minimum Investment** — 0.001 ETH minimum prevents spam

## Platform Fees
- 1.5% fee on successful raises
- 0.5% fee on each repayment
- Treasury: same address as deployer wallet

## Network
- **Chain:** Base Mainnet
- **Chain ID:** 8453
- **RPC:** https://mainnet.base.org
- **Explorer:** https://basescan.org

## Built With
- Solidity 0.8.20
- Hardhat 2.22
- OpenZeppelin Contracts
- viaIR optimizer enabled

## Setup
```bash
npm install
npx hardhat compile
npx hardhat test
```

## Deploy
```bash
npx hardhat run scripts/deploy.js --network base
```

## Test Results
All 47 tests passing ✅

## Security
- `notBlacklisted` modifier prevents defaulted addresses from re-raising
- Milestone-based fund release prevents misuse
- Auto-refund on deadline expiry or owner cancellation
- Minimum investment prevents dust attacks
- Exit marketplace includes seller verification
- Platform owner can resolve disputes and remove blacklists

## License
MIT
