// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "vrc25/contracts/VRC25.sol";

contract VRC25PCUSD is VRC25 {
  constructor() VRC25("Piltonet CUSD On Testnet", "PCUSD", 6) {
    _mint(msg.sender, 10000 * 10 ** 6); // mint 10000 PCUSD
  }

  function _estimateFee(
    uint256 value
  ) internal view virtual override returns (uint256) {
    return value * 0;
  }
}
