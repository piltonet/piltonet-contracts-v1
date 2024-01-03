import * as fs from 'fs';

async function main() {
  // copy contracts to piltonet-api and piltonet-web
  fs.cpSync(
    `${process.env.OUTCOME_CONTRACTS_PATH}/abi/`,
    `${process.env.PILTONETAPI_CONTRACTS_PATH}/abi/`,
    { recursive: true }
  )
  fs.cpSync(
    `${process.env.OUTCOME_CONTRACTS_PATH}/abi/`,
    `${process.env.PILTONETWEB_CONTRACTS_PATH}/abi/`,
    { recursive: true }
  )
  
  fs.cpSync(
    `${process.env.OUTCOME_CONTRACTS_PATH}/bytecode/`,
    `${process.env.PILTONETAPI_CONTRACTS_PATH}/bytecode/`,
    { recursive: true }
  )
  fs.cpSync(
    `${process.env.OUTCOME_CONTRACTS_PATH}/bytecode/`,
    `${process.env.PILTONETWEB_CONTRACTS_PATH}/bytecode/`,
    { recursive: true }
  )

  fs.cpSync(
    `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/`,
    `${process.env.PILTONETAPI_CONTRACTS_PATH}/deployments/`,
    { recursive: true }
  )
  fs.cpSync(
    `${process.env.OUTCOME_CONTRACTS_PATH}/deployments/`,
    `${process.env.PILTONETWEB_CONTRACTS_PATH}/deployments/`,
    { recursive: true }
  )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});