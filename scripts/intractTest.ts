import { ethers } from "hardhat";

async function main() {
  const contractAddress = "0x90c54C27c68B679b5213EAb309115D697F1093a5";

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