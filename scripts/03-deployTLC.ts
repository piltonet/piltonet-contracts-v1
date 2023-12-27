import { ethers } from "hardhat";
import * as fs from 'fs';

async function main() {
  const NETWORK = "victestnet";
  const abiDir = `${process.env.CONTRACTS_ABI_PATH}/abi`;
  const outcomeAbiDir = `${process.env.OUTCOME_CONTRACTS_PATH}/abi`;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // TrustedLendingCircle
  const TrustedLendingCircle = await ethers.deployContract("contracts/TrustedLendingCircle.sol:TrustedLendingCircle", [
    "0x0000000000000000000000000000000000000000", // payment_token
    30, // round_days
    0, // payment_type
    0, // creator_earnings_x10000
  ], {
    gasLimit: 6000000
  });
  const ContactsContract = {
    deployer: deployer.address,
    address: await TrustedLendingCircle.getAddress()
  }
  fs.writeFileSync(`${deploymentsDir}/TrustedLendingCircle.json`, JSON.stringify(ContactsContract))
  console.log("TrustedLendingCircle deployed to:", ContactsContract.address);

  // copy abi file to outcome/abi
  fs.copyFileSync(`${abiDir}/TrustedLendingCircle.json`, `${outcomeAbiDir}/TrustedLendingCircle.json`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});