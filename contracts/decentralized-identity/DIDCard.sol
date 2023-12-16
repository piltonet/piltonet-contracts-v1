// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Piltonet Decentralized Identity Card as NFT
contract DIDCard is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenId;

    constructor(address initialOwner) Ownable(initialOwner) ERC721("Piltonet Decentralized ID-card", "DIDC") {}

    function totalSupply() public view returns (uint256) {
        return _tokenId;
    }

    // function _burn(
    //     uint256 tokenId
    // ) internal override(ERC721, ERC721URIStorage) {
    //     super._burn(tokenId);
    // }

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

    function safeMint(address to, string memory uri) public onlyOwner {
        _tokenId++;
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);
    }
}
