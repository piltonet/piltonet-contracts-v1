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

    constructor(
        string memory baseURI,
        address _ERC6551Account,
        address _ERC6551Registry
    ) ERC721("Piltonet Profile", "PIP") Ownable(msg.sender) {
        _baseTokenURI = baseURI;

        AccountImplementation = _ERC6551Account;
        Registry = ERC6551Registry(_ERC6551Registry);
    }

    function createProfile(address mainAccount) public onlyOwner {
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
    }

    function totalSupply() external view returns (uint256) {
        return _tokenId;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    // The following functions are overrides required by Solidity.
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
