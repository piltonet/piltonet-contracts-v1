import { ethers } from "hardhat";

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const deploymentsDir = `.${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  const deployedERC721Profile = require(`${deploymentsDir}/ERC721Profile.json`);

  const Contract = await ethers.getContractAt("contracts/tba/ERC721Profile.sol:ERC721Profile", deployedERC721Profile.address);

  let totalSupply = await Contract.totalSupply();
  console.log('totalSupply: ', totalSupply);
  
  for(let i=1; i<=totalSupply; i++) {
    let tokenURI = await Contract.tokenURI(i);
    console.log('tokenID: ', i, 'tokenURI: ', tokenURI);
  }
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});