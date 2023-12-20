// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Profile.sol";

/// @custom:security-contact security@piltonet.com
contract ERC1155Contacts is ERC1155, Ownable, ERC1155Supply {
    
    address public ProfileImplementation;
    
    constructor(
      string memory baseURI,
      address _ERC721Profile
    )
        ERC1155(baseURI)
        Ownable(msg.sender)
    {
        ProfileImplementation = _ERC721Profile;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function addContact(address contactTBA, uint256 id) public {
        require(isProfileOwner(msg.sender, id) || msg.sender == owner(), "Error: Unauthorized request!");
        require(balanceOf(contactTBA, id) == 0, "Error: Contact has already been added!");
        
        _mint(contactTBA, id, 1, "");
    }
    
    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function uri(uint256 tokenId) public view override(ERC1155) returns (string memory) {
        return super.uri(tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual override(ERC1155) {
        require(to == address(0), "Error: Cannot transfer profile token.");
        return super.safeTransferFrom(from, to, id, value, data);
    }
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override(ERC1155) {
        require(to == address(0), "Error: Cannot transfer profile token.");
        return super.safeBatchTransferFrom(from, to, ids, values, data);
    }

    /*/////////////////////////////////////////////////////////
                        Getter Functions
    /////////////////////////////////////////////////////////*/

    /// @notice Check the owner of same tokenId in ERC721Profile contract
    function isProfileOwner(address account, uint256 id) public view returns (bool) {
        ERC721Profile Profile = ERC721Profile(ProfileImplementation);
        return Profile.ownerOf(id) == account;
    }
    
    /// @notice Check the owner of same tokenId in ERC721Profile contract
    function isValidContact(address contactTBA) public view returns (bool) {
        ERC721Profile Profile = ERC721Profile(ProfileImplementation);
        return Profile.tbaOwner(contactTBA) != address(0);
    }
}