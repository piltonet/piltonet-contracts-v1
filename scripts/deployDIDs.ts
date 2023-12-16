import { ethers } from "hardhat";
const fs = require('fs');

async function main() {
  const NETWORK = "victestnet";
  const deploymentsDir = `./deployments/${NETWORK}`;
  if (!fs.existsSync(deploymentsDir)) fs.mkdirSync(deploymentsDir);

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // DIDCard
  const DIDCard = await ethers.deployContract("DIDCard", {
    gasLimit: 4000000
  });
  const DIDCardContract = {
    deployer: deployer.address,
    address: await DIDCard.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/DIDCard.json`, JSON.stringify(DIDCardContract))
  console.log("DIDCard deployed to:", DIDCardContract.address);

  // DIDAccount
  const DIDAccount = await ethers.deployContract("DIDAccount", {
    gasLimit: 4000000
  });
  const DIDAccountContract = {
    deployer: deployer.address,
    address: await DIDAccount.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/DIDAccount.json`, JSON.stringify(DIDAccountContract))
  console.log("DIDAccount deployed to:", DIDAccountContract.address);

  // // DIDRegistry
  // const DIDRegistry = await ethers.deployContract("DIDRegistry", {
  //   gasLimit: 4000000
  // });
  // const DIDRegistryContract = {
  //   deployer: deployer.address,
  //   address: await DIDRegistry.getAddress()
  // }
  // fs.writeFileSync(`${deploymentsDir}/DIDRegistry.json`, JSON.stringify(DIDRegistryContract))
  // console.log("DIDRegistry deployed to:", DIDRegistryContract.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});