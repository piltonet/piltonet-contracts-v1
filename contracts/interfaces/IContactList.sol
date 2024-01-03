// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IContactList {
    /// @dev return all contacts of msg.sender
    function myContacts() external view returns (address[] memory);
    
    /// @dev return true if account is contact of msg.sender
    function isMyContact(address account) external view returns (bool);
}