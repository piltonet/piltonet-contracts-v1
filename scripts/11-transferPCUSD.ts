import { ethers } from "hardhat";

async function main() {
  const NETWORK = "victestnet";
  const deploymentsDir = `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  const deployedVRC25PCUSD = require(`.${deploymentsDir}/VRC25PCUSD.json`);
  const VRC25PCUSD = await ethers.getContractAt("contracts/VRC25PCUSD.sol:VRC25PCUSD", deployedVRC25PCUSD.address);

  // const _to = "0x94688d177029574FE9013006811261377FE52DD2";
  const _to = "0xa6927925013B55D316B1F80eBCa065E0Dcab601e"; // contract
  
  // transfer 10 PCUSD
  const tx = await VRC25PCUSD.transfer(_to, 10000000, {
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