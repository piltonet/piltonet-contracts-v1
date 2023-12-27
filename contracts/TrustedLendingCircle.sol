// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./utils/SafeMath.sol";

/// @title TrustedLendingCircle - TLC
/// @author Piltonet Team
/// @notice Piltonet on Viction
contract TrustedLendingCircle is Ownable(msg.sender) {
    using SafeERC20 for IERC20;
    using SafeMath for *;
    using Strings for *;

    /*********************************************************************************/
    /* CONSTANTS */
    /*********************************************************************************/

    uint16 public constant CONTRACT_VERSION = 1;

    uint8 internal constant CIRCLES_MIN_MEMBERS = 3; // Minimum number of members is 3 accounts
    uint8 internal constant CIRCLES_MAX_MEMBERS = 15; // Maximum number of members is 15 accounts
    address internal constant CIRCLES_PAYMENT_TOKEN0 = address(0); // VIC token (0x0000000000000000000000000000000000000000)
    address internal constant CIRCLES_PAYMENT_TOKEN1 = 0xdbf3CDb8Eed6d143b667B59EE15dE49A68D6DC1f; // CUSD contract address
    uint internal constant CIRCLES_MIN_PAY_X100_TOKEN0 = 10000; // Minimum payment each round is 100 VIC
    uint internal constant CIRCLES_MAX_PAY_X100_TOKEN0 = 50000; // Maximum payment each round is 500 VIC
    uint internal constant CIRCLES_MIN_PAY_X100_TOKEN1 = 10000; // Minimum payment each round is 100 CUSD
    uint internal constant CIRCLES_MAX_PAY_X100_TOKEN1 = 50000; // Maximum payment each round is 500 CUSD
    address internal constant CIRCLES_SERVICE_ADDRESS = 0xa61c159Ac42a3861d799D31bfE075B6E9a57C9f6; // Piltonet service pot address
    uint16 internal constant CIRCLES_SERVICE_CHARGE_X10000 = 20; // The service charge is 0.2%
    uint16 internal constant CIRCLES_MAX_CREATOR_EARNINGS_X10000 = 100; // The maximum creator earnings is 1%
    uint16 internal constant CIRCLES_MAX_PATIENCE_BENEFIT_X10000 = 3600; // The maximum benefit of patience (per year) is 36%

    /*********************************************************************************/
    /* VARIABLES */
    /*********************************************************************************/

    // Public
    // --------------------------------------------------------------------------------
    address public paymentToken;
    uint public startDate;

    // Private
    // --------------------------------------------------------------------------------
    string private circleName;
    uint16 private creatorEarnings; // Multiplied by Ten Thousand Times
    uint16 private roundDays;
    enum _paymentType {
        FIXED_PAY,
        FIXED_LOAN
    }
    _paymentType private paymentType;
    uint private fixedPay = 0 ether;
    uint private fixedLoan = 0 ether;
    uint8 private minMembers;
    uint8 private maxMembers;
    enum _winnersOrder {
        RANDOM,
        FIXED,
        AUCTION
    }
    _winnersOrder private winnersOrder;
    uint8 private winnersNumber;
    uint16 private patienceBenefit; // Multiplied by Ten Thousand Times
    enum _circleStatus {
        DEPLOYED,
        SETUPED,
        LAUNCHED,
        STARTED,
        PAUSED,
        STOPED,
        COMPLETED
    }
    _circleStatus private circleStatus;

    struct Invite {
        bool alive;
        address invitedBy;
        bool joined;
    }
    mapping(address => Invite) private invites;
    address[] private invitesAccounts;

    struct Member {
        bool alive;
        bool isModerator;
        uint8 selectedRound;
        uint totalPayments;
        uint loanAmount;
        bool debtor;
    }
    mapping(address => Member) private members;
    address[] private membersAccounts;

    mapping(uint8 => address) private selectedRounds;

    struct Winner {
        bool isWon;
        uint8 winRound;
        uint loanAmount;
    }
    mapping(address => Winner) private winners;
    address[] private winnersAccounts;

    uint8 private roundIndex = 0;
    uint8 private maxRounds = 0;

    /*********************************************************************************/
    /* EVENTSN */
    /*********************************************************************************/
    event LogStartOfRound(uint8 roundIndex);
    event LogEndOfCircle();

    /*********************************************************************************/
    /* MODIFIERS */
    /*********************************************************************************/
    modifier onlyModerators() {
        require(
            msg.sender == owner() ||
                (members[msg.sender].alive && members[msg.sender].isModerator)
        );
        _;
    }

    modifier onlyMembers() {
        require(msg.sender == owner() || members[msg.sender].alive);
        _;
    }

    /*********************************************************************************/
    /* CONSTRUCTOR */
    /*********************************************************************************/
    constructor(
        address payment_token,
        uint16 round_days,
        _paymentType payment_type,
        uint16 creator_earnings_x10000
    ) {
        require(
            payment_token == CIRCLES_PAYMENT_TOKEN0 ||
                payment_token == CIRCLES_PAYMENT_TOKEN1,
            "Error: Payment token is invalid."
        );
        require(
            creator_earnings_x10000 <= CIRCLES_MAX_CREATOR_EARNINGS_X10000,
            "Error: The patience benefit is out of range."
        );

        paymentToken = payment_token;
        roundDays = round_days;
        paymentType = payment_type;
        creatorEarnings = creator_earnings_x10000;
        circleStatus = _circleStatus.DEPLOYED;
    }

    /*********************************************************************************/
    /* FUNCTIONS */
    /*********************************************************************************/

    // Public - Only Owner
    // --------------------------------------------------------------------------------
    function setupCircle(
        string memory circle_name,
        uint fixed_pay_x100,
        uint fixed_loan_x100,
        uint8 min_members,
        uint8 max_members,
        _winnersOrder winners_order,
        uint8 winners_number,
        uint16 patience_benefit_x10000
    ) public onlyOwner {
        require(
            circleStatus == _circleStatus.DEPLOYED ||
                circleStatus == _circleStatus.SETUPED,
            "Error: The circle is launched."
        );
        if (paymentToken == CIRCLES_PAYMENT_TOKEN0) {
            if (paymentType == _paymentType.FIXED_PAY) {
                require(
                    fixed_pay_x100 >= CIRCLES_MIN_PAY_X100_TOKEN0 &&
                        fixed_pay_x100 <= CIRCLES_MAX_PAY_X100_TOKEN0,
                    "Error: The pay amount is out of range."
                );
            }
            if (paymentType == _paymentType.FIXED_LOAN) {
                require(
                    fixed_loan_x100 >=
                        CIRCLES_MIN_PAY_X100_TOKEN0.mul(max_members) &&
                        fixed_loan_x100 <=
                        CIRCLES_MAX_PAY_X100_TOKEN0.mul(min_members),
                    "Error: The pay amount is out of range."
                );
            }
        }
        if (paymentToken == CIRCLES_PAYMENT_TOKEN1) {
            if (paymentType == _paymentType.FIXED_PAY) {
                require(
                    fixed_pay_x100 >= CIRCLES_MIN_PAY_X100_TOKEN1 &&
                        fixed_pay_x100 <= CIRCLES_MAX_PAY_X100_TOKEN1,
                    "Error: The pay amount is out of range."
                );
            }
            if (paymentType == _paymentType.FIXED_LOAN) {
                require(
                    fixed_loan_x100 >=
                        CIRCLES_MIN_PAY_X100_TOKEN1.mul(max_members) &&
                        fixed_loan_x100 <=
                        CIRCLES_MAX_PAY_X100_TOKEN1.mul(min_members),
                    "Error: The pay amount is out of range."
                );
            }
        }
        require(
            min_members >= CIRCLES_MIN_MEMBERS &&
                min_members <= max_members &&
                max_members <= CIRCLES_MAX_MEMBERS,
            "Error: The number of members is out of range."
        );
        require(
            min_members.div(winners_number) >= CIRCLES_MIN_MEMBERS,
            "Error: The number of winners is too big."
        );
        require(
            patience_benefit_x10000 <= CIRCLES_MAX_PATIENCE_BENEFIT_X10000,
            "Error: The patience benefit is out of range."
        );

        circleName = circle_name;
        fixedPay = paymentType == _paymentType.FIXED_PAY
            ? (1 ether * fixed_pay_x100) / 10 ** 2
            : 0 ether;
        fixedLoan = paymentType == _paymentType.FIXED_LOAN
            ? (1 ether * fixed_loan_x100) / 10 ** 2
            : 0 ether;
        minMembers = min_members;
        maxMembers = max_members;
        winnersOrder = winners_order;
        winnersNumber = winners_number;
        patienceBenefit = patience_benefit_x10000;

        maxRounds = uint8(maxMembers.div(winnersNumber));
        circleStatus = _circleStatus.SETUPED;
    }

    function launchCircle(uint start_date) public onlyOwner {
        require(
            circleStatus == _circleStatus.SETUPED,
            "Error: The circle status is not ready for launch."
        );
        require(
            invitesAccounts.length >= CIRCLES_MIN_MEMBERS,
            "Error: The number of invited accounts before launch must be at least equal to the CIRCLES_MIN_MEMBERS."
        );
        require(
            start_date > 10 ** 9 &&
                start_date < 10 ** 10 && // Start date must be a 10-digit number
                start_date.div(60 * 60 * 24) >
                block.timestamp.div(60 * 60 * 24) && // and at least one day later
                start_date.div(60 * 60 * 24).mul(60 * 60 * 24) -
                    block.timestamp >
                60 * 60 * 12, // and at least 12 hours later
            "Error: The start date is out of range."
        );

        startDate = start_date.div(60 * 60 * 24).mul(60 * 60 * 24);
        circleStatus = _circleStatus.LAUNCHED;
        joinMember(winnersOrder == _winnersOrder.FIXED ? 1 : 0);
    }

    function addModerator(address account_address) public onlyOwner {
        require(members[account_address].alive);
        members[account_address].isModerator = true;
    }

    // Public - Only Moderators as well as Owner
    // --------------------------------------------------------------------------------
    function addInvites(address[] memory _invites) public onlyModerators {
        for (uint8 i = 0; i < _invites.length; i++) {
            if (!invites[_invites[i]].alive) {
                invites[_invites[i]] = Invite({
                    alive: true,
                    invitedBy: msg.sender,
                    joined: false
                });
                invitesAccounts.push(_invites[i]);
            }
        }
    }

    // Public - Only Members as well as Owner
    // --------------------------------------------------------------------------------
    function memberChangeRound(uint8 selected_round) public onlyMembers {
        require(
            winnersOrder == _winnersOrder.FIXED &&
                selected_round > 0 &&
                selectedRounds[selected_round] == address(0),
            "Error: The selected round is already chosen."
        );

        members[msg.sender].selectedRound = selected_round;
        selectedRounds[selected_round] = msg.sender;
    }

    function memberPayment() public payable onlyMembers {
        require(
            invites[msg.sender].alive,
            "Error: The circle status is not ready for launch."
        );
        uint _paid = paymentToken == address(0)
            ? msg.value
            : IERC20(paymentToken).balanceOf(msg.sender);
        if (paymentToken != address(0) && _paid > 0) {
            require(msg.value == 0, "Error: Invalid mint token");
            IERC20(paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                _paid
            );
        }
        members[msg.sender].totalPayments += _paid;
    }

    // Public
    // --------------------------------------------------------------------------------
    function acceptInvite(uint8 selected_round) public {
        require(
            invites[msg.sender].alive && !invites[msg.sender].joined,
            "Error: The circle status is not ready for launch."
        );
        joinMember(selected_round);
        invites[msg.sender].joined = true;
    }

    // Internal
    // --------------------------------------------------------------------------------
    function joinMember(uint8 selected_round) internal virtual {
        require(
            circleStatus == _circleStatus.LAUNCHED,
            "Error: The circle status is not ready for join."
        );
        require(!members[msg.sender].alive, "Error: Already a member.");
        require(
            membersAccounts.length < maxMembers,
            "Error: Membership capacity is full."
        );

        members[msg.sender] = Member({
            alive: true,
            isModerator: false,
            selectedRound: selected_round,
            totalPayments: 0,
            loanAmount: 0,
            debtor: false
        });
        membersAccounts.push(msg.sender);

        if (winnersOrder == _winnersOrder.FIXED)
            selectedRounds[selected_round] = msg.sender;
    }

    function roundDueDate(uint8 round_index) internal virtual returns (uint) {
        return
            startDate > 0 && round_index < maxRounds
                ? startDate.add(roundDays.mul(round_index).mul(60 * 60 * 24))
                : 0;
    }

    /*********************************************************************************/
    /* GETTER FUNCTIONS */
    /*********************************************************************************/

    // External - Only Moderators as well as Owner
    // --------------------------------------------------------------------------------
    function getInvitesAccounts()
        external
        view
        onlyModerators
        returns (address[] memory)
    {
        return invitesAccounts;
    }

    function getInviteByAddress(
        address account_address
    ) external view onlyModerators returns (Invite memory) {
        return invites[account_address];
    }

    // External - Only Members as well as Owner
    // --------------------------------------------------------------------------------
    function getMembersAccounts()
        external
        view
        onlyMembers
        returns (address[] memory)
    {
        return membersAccounts;
    }

    function getMemberByAddress(
        address account_address
    ) external view onlyMembers returns (Member memory) {
        return members[account_address];
    }

    // External
    // --------------------------------------------------------------------------------
    function getCircleDetails() external view returns (string memory) {
        string memory paymentType_ = paymentType == _paymentType.FIXED_PAY
            ? string(
                abi.encodePacked(
                    '"payment_type": "fixed_pay"',
                    ', "fixed_pay_x100": ',
                    fixedPay.mul(10 ** 2).div(1 ether).toString()
                )
            )
            : paymentType == _paymentType.FIXED_LOAN
            ? string(
                abi.encodePacked(
                    '"payment_type": "fixed_loan"',
                    ', "fixed_loan_x100": ',
                    fixedLoan.mul(10 ** 2).div(1 ether).toString()
                )
            )
            : '"payment_type": "undefined"';

        string memory winnersOrder_ = winnersOrder == _winnersOrder.FIXED
            ? "fixed"
            : winnersOrder == _winnersOrder.RANDOM
            ? "random"
            : winnersOrder == _winnersOrder.AUCTION
            ? "auction"
            : "undefined";

        string memory circleBaseInfo = string(
            abi.encodePacked(
                paymentType_,
                ', "round_days": ',
                roundDays.toString(),
                ', "creator_earnings_x10000": ',
                creatorEarnings.toString(),
                ', "service_charge_x10000": ',
                CIRCLES_SERVICE_CHARGE_X10000.toString()
            )
        );

        string memory circleDetails = circleStatus == _circleStatus.DEPLOYED
            ? Base64.encode(
                bytes(string(abi.encodePacked("{ ", circleBaseInfo, " }")))
            )
            : Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            "{ ",
                            circleBaseInfo,
                            ', "circle_name": "',
                            circleName,
                            '", "min_members": ',
                            minMembers.toString(),
                            ', "max_members": ',
                            maxMembers.toString(),
                            ', "winners_order": "',
                            winnersOrder_,
                            '", "winners_number": ',
                            winnersNumber.toString(),
                            ', "patience_benefit_x10000": ',
                            patienceBenefit.toString(),
                            " }"
                        )
                    )
                )
            );

        return
            string(
                abi.encodePacked("data:application/json;base64,", circleDetails)
            );
    }

    function getCircleStatus() external view returns (string memory) {
        return
            circleStatus == _circleStatus.DEPLOYED
                ? "deployed"
                : circleStatus == _circleStatus.SETUPED
                ? "setuped"
                : circleStatus == _circleStatus.LAUNCHED
                ? "launched"
                : circleStatus == _circleStatus.STARTED
                ? "started"
                : circleStatus == _circleStatus.COMPLETED
                ? "completed"
                : circleStatus == _circleStatus.PAUSED
                ? "paused"
                : circleStatus == _circleStatus.STOPED
                ? "stoped"
                : "undefined";
    }
}
