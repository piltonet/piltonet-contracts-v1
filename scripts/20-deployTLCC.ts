import { ethers } from "hardhat";
import * as fs from 'fs';
import getRevertReason from './getRevertReason';

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const abiDir = `${process.env.CONTRACTS_ABI_PATH}/abi`;
  const outcomeAbiDir = `${process.env.OUTCOME_CONTRACTS_PATH}/abi`;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // TLCC
  const TLCC = await ethers.deployContract("contracts/TLCC.sol:TLCC", [
    // process.env.SERVICE_ADMIN_PUBLIC_KEY, // service admin
    "0x0000000000000000000000000000000000000000", // address(0) for fully decentralized
    // "0x9C68ef09e85eF4615E63274BEE308361735b4c34", // tba
    "0x0000000000000000000000000000000000000000", // payment_token VIC
    // "0x093cD3E7806f6EadC76F9578fBF8BaCdf3aC7C3e", // payment_token CUSD
    "Mock TLCC", // circle_name
    5, // circle_size
    30, // round_days
    "10000000000000000000", // round_payments
    0, // winners_order
    0, // patience_benefit_x10000
    0 // creator_earnings_x10000
  ], {
    gasLimit: 6000000
  });

  console.log("Deploying contract in expected address:", await TLCC.getAddress());
  
  try {
    await TLCC.waitForDeployment();

    const ContactsContract = {
      deployer: deployer.address,
      address: await TLCC.getAddress()
    }
    fs.writeFileSync(`${deploymentsDir}/TLCC.json`, JSON.stringify(ContactsContract))
    console.log("TLCC deployed to:", ContactsContract.address);
  
    // copy abi file to outcome/abi
    fs.copyFileSync(`${abiDir}/TLCC.json`, `${outcomeAbiDir}/TLCC.json`);
    
    // copy bytecode to outcome/bytecode
    const outcomeByteCodeDir = `${process.env.OUTCOME_CONTRACTS_PATH}/bytecode`;
    const artifact = require('../artifacts/contracts/TLCC.sol/TLCC.json');
    const bytecode = artifact.bytecode;
    fs.writeFileSync(`${outcomeByteCodeDir}/TLCC.json`, JSON.stringify(bytecode))

  } catch(error: any) {
    const result = await getRevertReason(error.receipt.hash);
    console.error(result);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});