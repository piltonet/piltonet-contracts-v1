// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./tokenbound-account/ERC6551Registry.sol";
import "./utils/Utils.sol";

contract Profile is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenId;
    string private _baseTokenURI;

    address public AccountImplementation;
    ERC6551Registry public Registry;
    mapping(address => address) private _tba;

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Emitted when a profile has been created
    event ProfileCreated(uint256 indexed tokenId, address indexed account);

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/
    
    constructor(
        string memory baseURI,
        address _ERC6551Account,
        address _ERC6551Registry
    ) ERC721("Piltonet Profile", "PIP") Ownable(msg.sender) {
        _baseTokenURI = baseURI;

        AccountImplementation = _ERC6551Account;
        Registry = ERC6551Registry(_ERC6551Registry);
    }

    function createProfile(address mainAccount) public onlyOwner returns (address) {
        // each account can create a unique profile
        require(_tba[mainAccount] == address(0), "Error: Account has already been created!");

        // tokenId values start at 1
        _tokenId++;

        // compute TBA address
        address _tokenBoundAccount = Registry.account(
            AccountImplementation,
            block.chainid,
            address(this),
            _tokenId,
            0
        );

        // mint profilr NFT
        _safeMint(mainAccount, _tokenId);
        _setTokenURI(_tokenId, Utils.toString(_tokenBoundAccount));

        // save tba in contract and return that
        _tba[mainAccount] = _tokenBoundAccount;
        
        emit ProfileCreated(_tokenId, _tokenBoundAccount);

        return _tokenBoundAccount;
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
        require(to == address(0), "Error: Cannot transfer profile token.");
        return super.transferFrom(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
