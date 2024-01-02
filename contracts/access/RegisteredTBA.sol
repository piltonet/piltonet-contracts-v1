// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ServiceAdmin.sol";
import "./Constants.sol";
import "../tba/interfaces/IERC6551Account.sol";

abstract contract RegisteredTBA is ServiceAdmin {

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyTBAOwner() {
        require(
            getTBAProfile(msg.sender) == PILTONET_PROFILE_ADDRESS,
            "The sender is not a valid tokenbound-account."
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
}
