import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const abiDir = `${process.env.CONTRACTS_ABI_PATH}/abi`;
  const outcomeAbiDir = `${process.env.OUTCOME_CONTRACTS_PATH}/abi`;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;

  const deployedERC6551Account = require(`.${deploymentsDir}/ERC6551Account.json`);
  const deployedERC6551Registry = require(`.${deploymentsDir}/ERC6551Registry.json`);

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // ERC721Profile
  const ERC721Profile = await ethers.deployContract("contracts/tba/ERC721Profile.sol:ERC721Profile", [
    "https://piltonet.com/profile/",
    deployedERC6551Account.address,
    deployedERC6551Registry.address
  ], {
    gasLimit: 6000000
  });
  const ProfileContract = {
    deployer: deployer.address,
    address: await ERC721Profile.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/ERC721Profile.json`, JSON.stringify(ProfileContract))
  console.log("ERC721Profile deployed to:", ProfileContract.address);

  // copy abi file to outcome/abi
  fs.copyFileSync(`${abiDir}/ERC721Profile.json`, `${outcomeAbiDir}/ERC721Profile.json`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});