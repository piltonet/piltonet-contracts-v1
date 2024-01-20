// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract AcceptedTokens {
    
    address[] internal PAYMENT_TOKENS = [address(0), 0x093cD3E7806f6EadC76F9578fBF8BaCdf3aC7C3e]; // [VIC, CUSD]
    uint8[] internal TOKEN_DECIMAL = [18, 6];
    
    // Minimum Round Payment x 10**TOKEN_DECIMAL
    uint256[] internal MIN_ROUND_PAY = [
        10 * 10**TOKEN_DECIMAL[0], // VIC
        10 * 10**TOKEN_DECIMAL[1] // CUSD
    ];

    // Maximum Round Payment x 10**TOKEN_DECIMAL
    uint256[] internal MAX_ROUND_PAY = [
        500 * 10**TOKEN_DECIMAL[0], // VIC
        500 * 10**TOKEN_DECIMAL[1] // CUSD
    ]; 

    /**
     * @dev Returns the address of accepted tokens.
     */
    function acceptedTokens() public view virtual returns (address[] memory) {
        return PAYMENT_TOKENS;
    }

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    
    modifier onlyAcceptedTokens(address token) {
        require(
            isAcceptedTokens(token),
            "The token is not accepted."
        );
        _;
    }
    
    /*///////////////////////////////////////////////////////////////
                            Getters
    //////////////////////////////////////////////////////////////*/

    function isAcceptedTokens(address token) internal view returns (bool) {
        for (uint256 i = 0; i < PAYMENT_TOKENS.length; i++) {
            if (token == PAYMENT_TOKENS[i]) return true;
        }
        return false;
    }
    
    function getRoundPayment(address token) internal view
        onlyAcceptedTokens(token) 
        returns (
            uint256 minRoundPay,
            uint256 maxRoundPay
        ) {
        for (uint256 i = 0; i < PAYMENT_TOKENS.length; i++) {
            if (token == PAYMENT_TOKENS[i]) return (MIN_ROUND_PAY[i], MAX_ROUND_PAY[i]);
        }
    }
}
