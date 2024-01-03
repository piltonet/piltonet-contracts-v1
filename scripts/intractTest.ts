import { ethers } from "hardhat";

async function main() {
  const contractAddress = "0xb09a43508b5e0a0AFdc7a2e182b649d48b577ADa";

  const Contract = await ethers.getContractAt("contracts/TLCC.sol:TLCC", contractAddress);
  let circleName = await Contract.circleName();
  console.log('Circle Name: ', circleName);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});