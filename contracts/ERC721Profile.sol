// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./tba/lib/ERC6551Bytecode.sol";
import "./utils/Utils.sol";

contract ERC721Profile is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenId;
    string private _baseTokenURI;

    address public AccountImplementation;
    mapping(address => address) private _tba;
    uint256 public totalTBAs;

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
        address _ERC6551Account
    ) ERC721("Piltonet Profile", "PIP") Ownable(msg.sender) {
        _baseTokenURI = baseURI;

        AccountImplementation = _ERC6551Account;
    }

    function createProfile(address mainAccount) public onlyOwner returns (address) {
        // each account can create a unique profile
        require(_tba[mainAccount] == address(0), "Error: Account has already been created!");

        // tokenId values start at 1
        _tokenId++;

        // compute TBA address
        address _tbaAddress = _computeTBA(
            AccountImplementation,
            block.chainid,
            address(this),
            _tokenId,
            0
        );

        // mint profilr NFT
        _safeMint(mainAccount, _tokenId);
        _setTokenURI(_tokenId, Utils.toString(_tbaAddress));

        // save tba in contract and return that
        _tba[mainAccount] = _tbaAddress;
        totalTBAs++;
        
        emit ProfileCreated(_tokenId, _tbaAddress);

        return _tbaAddress;
    }

    function removeProfile(uint256 tokenId) public virtual {
        require(ownerOf(tokenId) == msg.sender, "Error, Only account owner can remove!");

        _update(address(0), tokenId, msg.sender);
        
        // reset tba address
        _tba[msg.sender] = address(0);
        totalTBAs--;
        
        emit RemoveProfile(_tokenId);
    }

    function getTBA(address mainAccount) external view returns (address) {
        return _tba[mainAccount];
    }
    
    function totalSupply() external view returns (uint256) {
        return _tokenId;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _computeTBA(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) internal view returns (address) {
        bytes32 bytecodeHash = keccak256(
            ERC6551Bytecode.getCreationCode(
                implementation,
                chainId,
                tokenContract,
                tokenId,
                salt
            )
        );

        return Create2.computeAddress(bytes32(salt), bytecodeHash);
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
