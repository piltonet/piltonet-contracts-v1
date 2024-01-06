import { ethers } from "hardhat";

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  const deployedVRC25PCUSD = require(`.${deploymentsDir}/VRC25PCUSD.json`);
  const VRC25PCUSD = await ethers.getContractAt("contracts/VRC25PCUSD.sol:VRC25PCUSD", deployedVRC25PCUSD.address);

  // const _to = "0x34732D8A991dCb0e76a06998B50327e4de98Ce8f";
  const _to = "0xC35756BC9C722f30307CBfdc234d2Af0c55d3c6D"; // contract
  
  // transfer 100 PCUSD
  const tx = await VRC25PCUSD.transfer(_to, 100000000, {
    gasLimit: 4000000
  });
  let _tx = await tx.wait();
  console.log(`Transfer to ${_to} tx:`, _tx);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});