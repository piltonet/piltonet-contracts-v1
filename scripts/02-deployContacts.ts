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

  // TrustedContacts
  const TrustedContacts = await ethers.deployContract("contracts/TrustedContacts.sol:TrustedContacts", [
    "https://piltonet.com/profile/",
    deployedERC721Profile.address
  ], {
    gasLimit: 6000000
  });
  const ContactsContract = {
    deployer: deployer.address,
    address: await TrustedContacts.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/TrustedContacts.json`, JSON.stringify(ContactsContract))
  console.log("TrustedContacts deployed to:", ContactsContract.address);

  // copy abi file to outcome/abi
  fs.copyFileSync(`${abiDir}/TrustedContacts.json`, `${outcomeAbiDir}/TrustedContacts.json`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});