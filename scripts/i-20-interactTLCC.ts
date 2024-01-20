import { ethers } from "hardhat";

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const deploymentsDir = `.${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  const deployedTLCC = require(`${deploymentsDir}/TLCC.json`);

  const Contract = await ethers.getContractAt("contracts/TLCC.sol:TLCC", deployedTLCC.address);
  
  let circleConstants = await Contract.getTLCCConstants();
  console.log('Circle Constants: ', JSON.parse(circleConstants));
  
  let serviceAdmin = await Contract.serviceAdmin();
  console.log('Service Admin: ', serviceAdmin);
  
  let circleName = await Contract.circleName();
  console.log('Circle Name: ', circleName);
  
  let circleStatus = await Contract.circleStatus();
  console.log('Circle Status: ', circleStatus);
  
  let contributionSize = await Contract.contributionSize();
  console.log('Contribution Size: ', contributionSize);
  
  let loanAmount = await Contract.loanAmount();
  console.log('Loan Amount: ', loanAmount);
  
  let paymentToken = await Contract.paymentToken();
  console.log('Payment Token: ', paymentToken);
  
  let currentRound = await Contract.currentRound();
  console.log('Current Round: ', currentRound);
  
  // let balance = await Contract.balance_();
  // console.log('balance: ', balance);
  
  // let sender = await Contract.sender_();
  // console.log('sender: ', sender);
  
  // let whitelistAddresses = await Contract.whitelistAddresses();
  // console.log('Circle Whitelist Addresses: ', whitelistAddresses);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});