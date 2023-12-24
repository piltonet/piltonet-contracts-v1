import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = "victestnet";
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  if (!fs.existsSync(deploymentsDir)) fs.mkdirSync(deploymentsDir);

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // ERC6551Account
  const ERC6551Account = await ethers.deployContract("ERC6551Account", {
    gasLimit: 4000000
  });
  const ERC6551AccountContract = {
    deployer: deployer.address,
    address: await ERC6551Account.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/ERC6551Account.json`, JSON.stringify(ERC6551AccountContract))
  console.log("ERC6551Account deployed to:", ERC6551AccountContract.address);

  // ERC6551Registry
  const ERC6551Registry = await ethers.deployContract("ERC6551Registry", {
    gasLimit: 4000000
  });
  const ERC6551RegistryContract = {
    deployer: deployer.address,
    address: await ERC6551Registry.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/ERC6551Registry.json`, JSON.stringify(ERC6551RegistryContract))
  console.log("ERC6551Registry deployed to:", ERC6551RegistryContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});