import { ethers } from "hardhat";

async function main() {
  const NETWORK = "victestnet";
  const chainId = 89;
  const deploymentsDir = `../deployments/${NETWORK}`;

  const deployedDIDCard = require(`${deploymentsDir}/DIDCard.json`);
  const deployedDIDAccount = require(`${deploymentsDir}/DIDAccount.json`);
  const deployedDIDRegistry = require(`${deploymentsDir}/DIDRegistry.json`);

  const DIDCard = await ethers.getContractAt("DIDCard", deployedDIDCard.address);
  const DIDAccount = await ethers.getContractAt("DIDAccount", deployedDIDAccount.address);
  const DIDRegistry = await ethers.getContractAt("DIDRegistry", deployedDIDRegistry.address);

  const _to = "0xf2137CF292bfBdF6B5C5458941E38Ea117AfC0f4";
  const _id = (await DIDCard.totalSupply()).toString() + 1;
  
  // Mint New DIDCard
  console.log(`Minting new DIDCard to: ${_to} id: ${_id}`);
  await DIDCard.safeMint(_to, "https://api.piltonet.com/did/{id}", {
    gasLimit: 6000000
  });
  console.log("Minting DIDCard Successfuly");

  // New DIDAccount Registry
  console.log("Creating a new DIDAccount");
  const newDIDAccount = await DIDRegistry.createAccount(
    deployedDIDAccount.address, // implementation contract
    chainId,
    deployedDIDCard.address, // parent NFT
    _id, // token ID
    0, // salt
    "0x", // init calldata
    {gasLimit: 6000000}
  );
  console.log("New DIDAccount Created:", newDIDAccount);

  // New DIDAccount Address 
  const newDIDAccountAddress = await DIDRegistry.account(
    deployedDIDAccount.address, // implementation contract
    chainId,
    deployedDIDCard.address, // parent NFT
    _id, // token ID
    0, // salt
  );
  console.log(`DIDAccount Address for ${_to} is:`, newDIDAccountAddress);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});