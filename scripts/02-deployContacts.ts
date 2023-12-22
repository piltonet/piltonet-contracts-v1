import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = "victestnet";
  const deploymentsDir = `./deployments/${NETWORK}`;

  const deployedERC721Profile = require(`.${deploymentsDir}/ERC721Profile.json`);

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // ERC1155Contacts
  const ERC1155Contacts = await ethers.deployContract("ERC1155Contacts", [
    "https://piltonet.com/profile/",
    // deployedERC721Profile.address
  ], {
    gasLimit: 4000000
  });
  const ContactsContract = {
    deployer: deployer.address,
    address: await ERC1155Contacts.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/ERC1155Contacts.json`, JSON.stringify(ContactsContract))
  console.log("ERC1155Contacts deployed to:", ContactsContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});