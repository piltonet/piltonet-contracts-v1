// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../constants/CService.sol";
import "../tba/interfaces/IERC6551Account.sol";

abstract contract RegisteredTBA is CService {

    /**
     * @dev Returns the address of the ERC721Profile contract.
     */
    function profileAddress() public view virtual returns (address) {
        return PILTONET_PROFILE_ADDRESS;
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyTBASender() {
        require(
            getTBAProfile(msg.sender) == PILTONET_PROFILE_ADDRESS,
            "The sender is not a valid tokenbound-account."
        );
        _;
    }
    
    modifier onlyTBAOwner(address account) {
        require(
            getTBAOwner(account) == msg.sender,
            "The sender is not the tokenbound-account owner."
        );
        _;
    }

    modifier onlyRegisteredTBA(address account) {
        require(
            getTBAProfile(account) == PILTONET_PROFILE_ADDRESS,
            "The account is not a valid tokenbound-account."
        );
        _;
    }
    
    /*///////////////////////////////////////////////////////////////
                            Getters
    //////////////////////////////////////////////////////////////*/

    function getTBATokenId(address account) internal view returns (uint256) {
        (, , uint256 tokenId) = IERC6551Account(payable(account)).token();
        return tokenId;
    }

    function getTBAProfile(address account) internal view returns (address) {
        (, address profileAddr, ) = IERC6551Account(payable(account)).token();
        return profileAddr;
    }

    function getTBAOwner(address account) internal view onlyRegisteredTBA(account) returns (address) {
        return IERC6551Account(payable(account)).owner();
    }
}
