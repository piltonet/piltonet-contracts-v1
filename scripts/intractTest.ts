import { ethers } from "hardhat";

async function main() {
  const contractAddress = "0xd01c53779bb6f2482758D46b596d728E90774394";

  const Contract = await ethers.getContractAt("contracts/TLCC.sol:TLCC", contractAddress);
  let circleName = await Contract.circleName();
  console.log('Circle Name: ', circleName);
  
  let circleStatus = await Contract.circleStatus();
  console.log('Circle Status: ', circleStatus);
  
  // let whitelistAddresses = Contract.whitelistAddresses();
  // console.log('Circle Whitelist Addresses: ', whitelistAddresses);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});