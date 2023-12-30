import { HardhatUserConfig } from 'hardhat/types';
import '@nomicfoundation/hardhat-toolbox'
import 'hardhat-abi-exporter';
import 'dotenv/config'

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  abiExporter: {
    path: `${process.env.CONTRACTS_ABI_PATH}/abi`,
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
  },
  defaultNetwork: "victestnet",
  networks: {
    victestnet: {
      url: "https://rpc-testnet.viction.xyz",
      accounts: [process.env.PRIVATE_KEY || ""]
    },
    viction: {
      url: "https://rpc.tomochain.com",
      accounts: [process.env.PRIVATE_KEY || ""]
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
