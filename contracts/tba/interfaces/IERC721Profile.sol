// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IERC721Profile {
    /// @notice return the number of exist tokenbound-accounnts
    function tokenOf(address account) external view returns (uint256, address);
}