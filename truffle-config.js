const HDWalletProvider = require('@truffle/hdwallet-provider');
const path = require("path");
require("dotenv").config();

const bscPrivKey = process.env.BSC_PRIV_KEY.replace(/1/g, "_"); // to prevent accidental deploys;
const ganachePrivKey = process.env.GANACHE_PRIV_KEY;

module.exports = {
  networks: {
    development: {
      provider: () => new HDWalletProvider(ganachePrivKey, `http://localhost:7545`),
      network_id: 5777
    },
    testnet: {
      provider: () => new HDWalletProvider(bscPrivKey, `https://data-seed-prebsc-1-s1.binance.org:8545`),
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    },
    bsc: {
      provider: () => new HDWalletProvider(bscPrivKey, `https://bsc-dataseed1.binance.org`),
      network_id: 56,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true
    }
  },
  plugins: [
    'truffle-contract-size'
  ],
  contracts_directory: path.resolve('./contracts/'),
  contracts_build_directory: path.resolve('../webpage/src/app/blockchain/abis'),
  compilers: {
    solc: {
      version: "0.8.10", 
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}
