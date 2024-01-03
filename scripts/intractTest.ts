import { ethers } from "hardhat";

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const deploymentsDir = `.${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;

  const deployedContract = require(`${deploymentsDir}/TrustedContacts.json`);
  
  const Contract = await ethers.getContractAt("contracts/TrustedContacts.sol:TrustedContacts", deployedContract.address);
  let serviceAdmin = await Contract.serviceAdmin();
  console.log('Service Admin: ', serviceAdmin);
  let profileAddress = await Contract.profileAddress();
  console.log('Profile Address: ', profileAddress);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});