import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = "victestnet";
  const abiDir = `${process.env.CONTRACTS_ABI_PATH}/abi`;
  const outcomeAbiDir = `${process.env.OUTCOME_CONTRACTS_PATH}/abi`;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // VRC25PCUSD
  const VRC25PCUSDContract = await ethers.deployContract("contracts/VRC25PCUSD.sol:VRC25PCUSD", {
    gasLimit: 4000000
  });
  const PCUSDContract = {
    deployer: deployer.address,
    address: await VRC25PCUSDContract.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/VRC25PCUSD.json`, JSON.stringify(PCUSDContract))
  console.log("VRC25PCUSD deployed to:", PCUSDContract.address);

  // copy abi file to outcome/abi
  fs.copyFileSync(`${abiDir}/VRC25PCUSD.json`, `${outcomeAbiDir}/VRC25PCUSD.json`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});