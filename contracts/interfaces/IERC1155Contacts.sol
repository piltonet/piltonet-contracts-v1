// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ITrustedContacts {
    /// @notice return the number of exist tokenbound-accounnts
    function contactsOf(address account) external view returns (address[] memory);
}