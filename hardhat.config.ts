import { HardhatUserConfig } from 'hardhat/types';
import '@nomicfoundation/hardhat-toolbox'
import 'hardhat-abi-exporter';
import 'dotenv/config'

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  abiExporter: {
    path: process.env.CONTRACT_ABI_PATH,
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
  },
  defaultNetwork: "victestnet",
  networks: {
    victestnet: {
      url: "https://rpc.testnet.tomochain.com",
      accounts: [process.env.PRIVATE_KEY || ""]
    },
    vicmainnet: {
      url: "https://rpc.tomochain.com",
      accounts: [process.env.PRIVATE_KEY || ""]
    }
  }
}

export default config;
