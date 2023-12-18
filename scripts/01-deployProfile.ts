import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = "victestnet";
  const deploymentsDir = `./deployments/${NETWORK}`;

  const deployedERC6551Account = require(`.${deploymentsDir}/ERC6551Account.json`);
  const deployedERC6551Registry = require(`.${deploymentsDir}/ERC6551Registry.json`);

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Profile
  const Profile = await ethers.deployContract("Profile", [
    "https://piltonet.com/profile/",
    deployedERC6551Account.address,
    deployedERC6551Registry.address
  ], {
    gasLimit: 4000000
  });
  const ProfileContract = {
    deployer: deployer.address,
    address: await Profile.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/Profile.json`, JSON.stringify(ProfileContract))
  console.log("Profile deployed to:", ProfileContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});