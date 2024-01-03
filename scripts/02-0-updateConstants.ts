import * as fs from 'fs';

async function main() {
  const NETWORK = process.env.DEFAULT_NETWORK;
  const deploymentsDir = `.${process.env.OUTCOME_CONTRACTS_PATH}/deployments/${NETWORK}`;
  const deployedERC721Profile = require(`${deploymentsDir}/ERC721Profile.json`);

  let newConstants = `// SPDX-License-Identifier: MIT
  pragma solidity ^0.8.20;
  
  abstract contract Constants {
      // Piltonet Services Admin
      address internal constant PILTONET_SERVICE_ADMIN = 0xa61c159Ac42a3861d799D31bfE075B6E9a57C9f6;
      
      // ERC721Profile Implementation
      address internal constant PILTONET_PROFILE_ADDRESS = ${deployedERC721Profile.address};
  }`;

  fs.writeFileSync("./contracts/access/Constants.sol", newConstants);
  console.log("Constants updated to:", newConstants);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});