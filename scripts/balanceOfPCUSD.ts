import { ethers } from "hardhat";

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  const deployedVRC25PCUSD = require(`.${deploymentsDir}/VRC25PCUSD.json`);
  const VRC25PCUSD = await ethers.getContractAt("contracts/VRC25PCUSD.sol:VRC25PCUSD", deployedVRC25PCUSD.address);

  // const account = "0x94688d177029574FE9013006811261377FE52DD2";
  const account = "0xa6927925013B55D316B1F80eBCa065E0Dcab601e"; // contract

  const balance = await VRC25PCUSD.balanceOf(account);
  console.log(`Balance of ${account}:`, balance);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});