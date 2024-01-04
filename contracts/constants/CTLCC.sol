// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract CTLCC {
    /*///////////////////////////////////////////////////////////////
                            Constants
    //////////////////////////////////////////////////////////////*/
    // Maximum fee (in 1/1000s) from dispersements that is shared between other members
    uint16 internal constant MAX_FEE_IN_X1000 = 20;

    // Start time of the TLCC must be not more than this much time ago when the TLCC is created
    // This is to prevent accidental or malicious deployment of TLCCs that are supposedly
    // already in round number X > 1 and participants are supposedly delinquent.
    uint32 internal constant MAXIMUM_TIME_PAST_SINCE_TLCC_START_SECS = 900; // 15 minutes

    // the winning bid must be at least this much of the maximum (aka default) pot value
    uint8 internal constant MIN_DISTRIBUTION_PERCENT = 65;

    // Every new bid has to be at most this much of the previous lowest bid
    uint8 internal constant MAX_NEXT_BID_RATIO = 98;

    // Service account from which Escape Hatch can be enabled.
    address internal constant ESCAPE_HATCH_ENABLER = 0x2B27F8c647872BC0f5E4C7cA8e3aEAEe19A28f3A;

    uint8 internal constant CIRCLES_MIN_MEMBERS = 3; // Minimum number of members is 3 accounts
    uint8 internal constant CIRCLES_MAX_MEMBERS = 15; // Maximum number of members is 15 accounts
    address internal constant CIRCLES_PAYMENT_TOKEN0 = address(0); // VIC token (0x0000000000000000000000000000000000000000)
    address internal constant CIRCLES_PAYMENT_TOKEN1 =
        0x093cD3E7806f6EadC76F9578fBF8BaCdf3aC7C3e; // CUSD contract address
    uint internal constant CIRCLES_MIN_PAY_X100_TOKEN0 = 10000; // Minimum payment each round is 100 VIC
    uint internal constant CIRCLES_MAX_PAY_X100_TOKEN0 = 50000; // Maximum payment each round is 500 VIC
    uint internal constant CIRCLES_MIN_PAY_X100_TOKEN1 = 10000; // Minimum payment each round is 100 CUSD
    uint internal constant CIRCLES_MAX_PAY_X100_TOKEN1 = 50000; // Maximum payment each round is 500 CUSD
    address internal constant CIRCLES_SERVICE_ADDRESS =
        0x2B27F8c647872BC0f5E4C7cA8e3aEAEe19A28f3A; // Piltonet service pot address
    uint16 internal constant CIRCLES_SERVICE_CHARGE_X10000 = 20; // The service charge is 0.2%
    uint16 internal constant CIRCLES_MAX_CREATOR_EARNINGS_X10000 = 500; // The maximum creator earnings is 5%
    uint16 internal constant CIRCLES_MAX_PATIENCE_BENEFIT_X10000 = 3600; // The maximum benefit of patience (per year) is 36%
}
