// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./ERC721Profile.sol";

/// @custom:security-contact security@piltonet.com
contract ERC1155Contacts is ERC1155, Ownable, ERC1155Supply {
    ERC721Profile public Profile;
    
    constructor(
      string memory baseURI,
      address _ERC721Profile
    )
        ERC1155(baseURI)
        Ownable(msg.sender)
    {
        Profile = ERC721Profile(_ERC721Profile);
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function addContact(address account, uint256 id)
        public
    {
        require(msg.sender == Profile.ownerOf(id) || msg.sender == owner(), "Error: Only profile tokenbound-accound can do!");
        
        _mint(account, id, 1, "");
    }
    
    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    /*/////////////////////////////////////////////////////////
                        Getter Functions
    /////////////////////////////////////////////////////////*/

    /// @notice Check the owner of tokenId in ERC721Profile 
    function isProfileOwner(address mainAccount, uint256 id) external view returns (bool) {
        return Profile.ownerOf(id) == mainAccount;
    }
}
