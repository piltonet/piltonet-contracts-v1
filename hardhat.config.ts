import { HardhatUserConfig } from 'hardhat/types';
import '@nomicfoundation/hardhat-toolbox'
import 'hardhat-abi-exporter';
import 'dotenv/config'

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  abiExporter: {
    path: `${process.env.CONTRACTS_ABI_PATH}/abi`,
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
  },
  defaultNetwork: process.env.DEFAULT_NETWORK,
  networks: {
    viction: {
      url: "https://rpc.viction.xyz",
      accounts: [process.env.SERVICE_ADMIN_PRIVATE_KEY || ""]
    },
    victestnet: {
      url: "https://rpc-testnet.viction.xyz",
      accounts: [process.env.SERVICE_ADMIN_PRIVATE_KEY || ""]
    },
    tomotestnet: {
      url: "https://rpc.testnet.tomochain.com",
      accounts: [process.env.SERVICE_ADMIN_PRIVATE_KEY || ""]
    }
  },
  etherscan: {
    apiKey: {
      victestnet: "tomoscan2023",
    },
    customChains: [
      {
        network: "victestnet",
        chainId: 89,
        urls: {
          apiURL: "https://scan-api-testnet.viction.xyz/api/contract/hardhat/verify",
          browserURL: "https://www.testnet.vicscan.xyz"
        }
      }
    ]
  }
}

export default config;
