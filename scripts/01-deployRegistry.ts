import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const abiDir = `${process.env.CONTRACTS_ABI_PATH}/abi`;
  const outcomeAbiDir = `${process.env.OUTCOME_CONTRACTS_PATH}/abi`;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  if (!fs.existsSync(deploymentsDir)) fs.mkdirSync(deploymentsDir);
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // ERC6551Registry
  const ERC6551Registry = await ethers.deployContract("contracts/tba/ERC6551Registry.sol:ERC6551Registry", {
    gasLimit: 6000000
  });
  const ERC6551RegistryContract = {
    deployer: deployer.address,
    address: await ERC6551Registry.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/ERC6551Registry.json`, JSON.stringify(ERC6551RegistryContract))
  console.log("ERC6551Registry deployed to:", ERC6551RegistryContract.address);

  // copy abi file to outcome/abi
  fs.copyFileSync(`${abiDir}/ERC6551Registry.json`, `${outcomeAbiDir}/ERC6551Registry.json`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});