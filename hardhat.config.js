require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      viaIR: true,
      optimizer: { enabled: true, runs: 200 }
    }
  },
  networks: {
    // ── Mainnets ──────────────────────────
    base: {
      url: "https://mainnet.base.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 8453
    },
    polygon: {
      url: "https://polygon-rpc.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 42161
    },
    optimism: {
      url: "https://mainnet.optimism.io",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 10
    },
    bnb: {
      url: "https://bsc-dataseed.binance.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 56
    },
    ethereum: {
      url: "https://eth.llamarpc.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 1
    },

    // ── Testnets ──────────────────────────
    baseSepolia: {
      url: "https://sepolia.base.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 84532
    },
    polygonMumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 80001
    }
  },
  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
      arbitrumOne: process.env.ARBISCAN_API_KEY,
      optimisticEthereum: process.env.OPTIMISM_API_KEY,
      bsc: process.env.BSCSCAN_API_KEY,
      mainnet: process.env.ETHERSCAN_API_KEY
    },
    customChains: [{
      network: "base",
      chainId: 8453,
      urls: {
        apiURL: "https://api.basescan.org/api",
        browserURL: "https://basescan.org"
      }
    }]
  }
};
