// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Constants.sol";
import "../interfaces/IContactList.sol";

abstract contract TrustedContact is Constants {

    /**
     * @dev Returns the address of the ContactList contract.
     */
    function contactListAddress() public view virtual returns (address) {
        return PILTONET_CONTACTLIST_ADDRESS;
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyTrustedContact(address account) {
        require(
            isTrustedContact(account),
            "The account is not a trusted contact."
        );
        _;
    }
    
    modifier onlyTrustedContacts(address[] memory accounts) {
        require(
            areTrustedContacts(accounts),
            "Not all accounts are trusted contact."
        );
        _;
    }
    
    
    /*///////////////////////////////////////////////////////////////
                            Getters
    //////////////////////////////////////////////////////////////*/

    function isTrustedContact(address account) internal view returns (bool) {
        return IContactList(payable(PILTONET_CONTACTLIST_ADDRESS)).isMyContact(account);
    }

    function areTrustedContacts(address[] memory accounts) internal view returns (bool) {
        IContactList _ContactList = IContactList(payable(PILTONET_CONTACTLIST_ADDRESS));
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!_ContactList.isMyContact(accounts[i])) return false;
        }
        return true;
    }

}
