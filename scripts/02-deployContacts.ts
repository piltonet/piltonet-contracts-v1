import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const abiDir = `${process.env.CONTRACTS_ABI_PATH}/abi`;
  const outcomeAbiDir = `${process.env.OUTCOME_CONTRACTS_PATH}/abi`;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;

  const deployedERC721Profile = require(`.${deploymentsDir}/ERC721Profile.json`);

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // ERC1155Contacts
  const ERC1155Contacts = await ethers.deployContract("contracts/ERC1155Contacts.sol:ERC1155Contacts", [
    "https://piltonet.com/profile/",
    deployedERC721Profile.address
  ], {
    gasLimit: 6000000
  });
  const ContactsContract = {
    deployer: deployer.address,
    address: await ERC1155Contacts.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/ERC1155Contacts.json`, JSON.stringify(ContactsContract))
  console.log("ERC1155Contacts deployed to:", ContactsContract.address);

  // copy abi file to outcome/abi
  fs.copyFileSync(`${abiDir}/ERC1155Contacts.json`, `${outcomeAbiDir}/ERC1155Contacts.json`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});