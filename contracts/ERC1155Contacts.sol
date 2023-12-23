// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./tba/interfaces/IERC6551Account.sol";
import "./utils/Utils.sol";

/// @title Piltonet Contacts - ERC1155 contract
/// @author @FAR0KH
/// @notice This contract is used to store trust relationships between accounts registered in Profile contract
/// @custom:security-contact security@piltonet.com
contract ERC1155Contacts is ERC1155, ERC1155Supply, Ownable {
    
    /// @dev save tba as main owner of its tokenId 
    mapping(uint256 => address) private _idOwner;
    
    /// @dev save all contacts by tokenId
    mapping(uint256 => address[]) private _allContacts;
    
    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    
    event ContactAdded(uint256 indexed tokenId, address indexed account, address indexed contact);

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyTBAOwner(address account) {
        require(
            IERC6551Account(payable(account)).owner() == msg.sender,
            "The sender is not the owner of tokenbound-account."
        );
        _;
    }
    
    modifier onlyRegisteredTBA(address account) {
        require(
            IERC6551Account(payable(account)).owner() != address(0),
            "The account is not a valid tokenbound-account."
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/
    
    constructor(
      string memory baseURI
    )
        ERC1155(baseURI)
        Ownable(msg.sender)
    {}

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    function addContact(address senderTBA, address contactTBA) public
        onlyTBAOwner(senderTBA)
        onlyRegisteredTBA(contactTBA)
    {
        require(senderTBA != contactTBA, "Error: The account cannot be its own contact!");

        /// @dev get tokenbound-account tokenId from ERC6551Account
        uint256 tokenId = getTBATokenId(senderTBA);

        /// @dev save tba as main owner of its tokenId 
        _idOwner[tokenId] = senderTBA;

        require(balanceOf(contactTBA, tokenId) == 0, "Error: Contact has already been added!");
        
        _mint(contactTBA, tokenId, 1, "");

        _allContacts[tokenId].push(contactTBA);

        emit ContactAdded(tokenId, senderTBA, contactTBA);
    }

    function contactsOf(uint256 id) public view returns (address[] memory) {
        return _allContacts[id];
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    
    /// @notice return the URI same as ERC721Profile tokenURI
    function uri(uint256 tokenId) public view override(ERC1155) returns (string memory) {
        return string(abi.encodePacked(
            ERC1155.uri(tokenId),
            Utils.toString(_idOwner[tokenId])
        ));
    }

    /// @dev override ERC1155 safeTransferFrom to avoid transfer tokens
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override(ERC1155) onlyOwner {
        return super.safeTransferFrom(from, to, id, value, data);
    }
    
    /// @dev override ERC1155 safeTransferFrom to avoid transfer tokens
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override(ERC1155) onlyOwner {
        return super.safeBatchTransferFrom(from, to, ids, values, data);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    /*///////////////////////////////////////////////////////////////
                            Getters
    //////////////////////////////////////////////////////////////*/

    function getTBATokenId(address account) internal view returns (uint256) {
        (, , uint256 tokenId) = IERC6551Account(payable(account)).token();
        return tokenId;
    }
}