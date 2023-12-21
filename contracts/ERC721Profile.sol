// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./tba/ERC6551Registry.sol";
import "./utils/Utils.sol";

contract ERC721Profile is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenId;
    string private _baseTokenURI;

    // ERC6551Account address
    address internal _AccountImplementation;

    // ERC6551Registry contract
    ERC6551Registry internal _ERC6551Registry;

    mapping(address => uint256) private _tokenIdOf;
    mapping(address => address) private _tbaOwner;
    uint256 private _totalTBAs;

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    
    event ProfileCreated(uint256 indexed tokenId, address indexed account);
    event RemoveProfile(uint256 indexed tokenId);

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/
    
    constructor(
        string memory baseURI,
        address ERC6551AccountAdr,
        address ERC6551RegistryAdr
    ) ERC721("Piltonet Profile", "PIP") Ownable(msg.sender) {
        _baseTokenURI = baseURI;
        
        // set ERC6551 contracts
        _AccountImplementation = ERC6551AccountAdr;
        _ERC6551Registry = ERC6551Registry(ERC6551RegistryAdr);
    }

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    // mint profile NFT
    function createProfile(address mainAccount) public onlyOwner returns (uint256) {
        // each account can create a unique profile
        require(balanceOf(mainAccount) == 0, "Error: Profile has already been created!");

        // tokenId values start at 1
        _tokenId++;

        // mint profilr NFT
        _safeMint(mainAccount, _tokenId);

        // compute TBA address
        // address _tbaAddress = tbaOf(_tokenId);
        address _tbaAddress = _ERC6551Registry.createAccount(
            _AccountImplementation,
            block.chainid,
            address(this),
            _tokenId,
            0,
            ""
        );

        // tokenURI = baseURI + tbaAddress
        _setTokenURI(_tokenId, Utils.toString(_tbaAddress));

        // save profile tba owners
        _tokenIdOf[_tbaAddress] = _tokenId;
        _tbaOwner[_tbaAddress] = mainAccount;
        _totalTBAs++;
        
        emit ProfileCreated(_tokenId, _tbaAddress);

        return _tokenId;
    }

    // burn profile NFT
    function removeProfile(uint256 tokenId) public virtual {
        require(ownerOf(tokenId) == msg.sender, "Error, Only account owner can remove!");

        // reset token ownership
        _update(address(0), tokenId, msg.sender);
        
        // compute TBA address
        address _tbaAddress = tbaOf(tokenId);

        // delete tba address
        delete _tbaOwner[_tbaAddress];
        
        emit RemoveProfile(tokenId);
    }

    // return the token bound accounnt by token id, if id not exist return address(0)
    function tbaOf(uint256 tokenId) internal view returns (address) {
        if(ownerOf(tokenId) == address(0)) return address(0);
        return _ERC6551Registry.account(
            _AccountImplementation,
            block.chainid,
            address(this),
            tokenId,
            0
        );
    }
    
    // return the owner on token bound account
    function tbaOwner(address tokenBoundAccound) external view returns (address) {
        return _tbaOwner[tokenBoundAccound];
    }
    
    // return the number of active token bound accounnts
    function totalTBAs() external view returns (uint256) {
        return _totalTBAs;
    }
    
    function totalSupply() external view returns (uint256) {
        return _tokenId;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }


    // The following functions are overrides required by Solidity.
    
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721, IERC721) {
        require(tokenId == 0, "Error: Cannot transfer profile token.");
        return super.transferFrom(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
