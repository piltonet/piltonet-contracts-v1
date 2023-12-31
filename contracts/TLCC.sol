// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "vrc25/contracts/interfaces/IVRC25.sol";
import "./access/ServiceAdmin.sol";
import "./access/RegisteredTBA.sol";
import "./access/TrustedContact.sol";
import "./interfaces/ITLCC.sol";
import "./constants/CTLCC.sol";
import "./utils/SafeMath.sol";

/// @title Trusted Lending Circle Contract - TLCC
/// @notice TLCC on Viction
/// @dev Supports VIC and CUSD (+ any VRC25 tokens)
/*///////////////////////////////////////////////////////////////
A TLCC (Trusted Lending Circle Contract) is an agreement between trusted
family and friends to contribute regularly to a pool of funds and give it
all to one or more members (termed "Winner") until everyone in the group
gets their chance.
The person who deploys the TLCC is known as the contract owner (termed "Admin").
Admin specifies the main parameters of the circle while deploying the TLCC.
Such as payment token, length of each period, etc.
//////////////////////////////////////////////////////////////*/
contract TLCC is ITLCC, CTLCC, ServiceAdmin, RegisteredTBA, TrustedContact {
    using SafeMath for *;
	
    uint16 public constant TLCC_VERSION = 2;

    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    // To Do for test
    uint256 public balance_ = 13; 
    address public sender_;

    address internal circleAdmin;
    address public paymentToken; // public - allow easy verification of token contract.

    // Payment Type
    enum _paymentType {
        FIXED_PAY, // 0 : Loan amount will be based on the number of members and other rules. (FIXED_PAY)
        FIXED_LOAN // 1 : Contribution amount will be based on the number of members and other rules. (FIXED_LOAN)
    }
    _paymentType paymentType;

    uint16 internal roundDays;

    // Winners Order
    enum _winnersOrder {
        RANDOM, // 0 : Winner(s) is/are chosen at random (RANDOM)
        FIXED, // 1 : Winner(s) is/are selected through a predetermined ordered list (FIXED)
        BIDDING // 2 : Lowest bidder wins (BIDDING)
    }
    _winnersOrder winnersOrder;

    uint16 internal creatorEarnings; // Multiplied by Ten Thousand Times
    uint16 internal patienceBenefit; // Multiplied by Ten Thousand Times
    // Circle Status
    enum _circleStatus {
        DEPLOYED,
        SETUPED,
        LAUNCHED,
        STARTED,
        PAUSED,
        STOPED,
        COMPLETED
    }
    _circleStatus public circleStatus; // To Do internal - public temp, for easy test

    // TLCC parameters
    string public circleName; // To Do internal - public temp, for easy test
    uint256 public contributionSize; // To Do internal - public temp, for easy test
    uint256 public loanAmount; // To Do internal - public temp, for easy test
    uint8 private minMembers;
    uint8 private maxMembers;
    uint8 private winnersNumber;
    uint8 private maxRounds = 0;

    // To Do currentRound
    uint16 public currentRound = 1; // circle is started the moment it is created
    
    uint256 public startDate; // To Do internal - public temp, for easy test
    uint256 internal startTime;

    //
    uint16 internal serviceFeeInThousandths;
    uint256 internal roundPeriodInSecs;

    // The list of contacts who are whitelisted to join the circle
    struct Whitelist {
        bool alive; // needed to check If it has already been added to the whitelist
        address listedBy; // The moderator's address who whitelist this person
        bool joined; // true if the person has joined as a member
    }
    mapping(address => Whitelist) private whitelist;
    address[] private whitelistAddresses; // for iterating through whitelist's addresses

    struct Member {
        bool alive; // needed to check if a member is indeed a member
        uint8 selectedRound; // in fixed type of tlcc
        uint256 totalPayments; // the total amount paid by member
        uint256 loanAmount; // the total amount borrowed by member
        uint256 credit; // amount of funds member has contributed - winnings (not including discounts) so far
        bool paid; // yes if the member had won a Round
        bool debtor; // true if member won the pot while not in good standing and is still not in good standing
        bool isModerator; // true if the member is a moderator of the circle
        
    }
    mapping(address => Member) public members; // To Do private - public temp, for easy test
    address[] private membersAddresses; // for iterating through members' addresses

    mapping(uint8 => address) private selectedRounds;





    bool public endOfTLCC = false;
    bool public adminSurplusCollected = false;
    // A discount is the difference between a winning bid and the pot value. totalDiscounts is the amount
    // of discounts accumulated so far
    uint256 public totalDiscounts = 0;

    // Amount of fees reserved in the contract for fees.
    uint256 public totalFees = 0;

    // Round state variables
    uint256 public lowestBid = 0;
    address public winnerAddress = address(0); // bidder who bid the lowest so far

    

    // Other state
    // An escape hatch is used in case a major vulnerability is discovered in the contract code.
    // The following procedure is then put into action:
    // 1. Service sends a transaction to make escapeHatchEnabled true.
    // 2. admin is notified and can decide to activate the escapeHatch.
    // 3. If escape hatch is activated, no contributions and/or withdrawals are allowed. The admin
    //    may call withdraw() to withdraw all of the contract's funds and then disperse them offline
    //    among the participants.
    bool public escapeHatchEnabled = false;
    bool public escapeHatchActive = false;
    bool private reentrancyLock = false;

    /*///////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/
    modifier nonReentrant() {
        require(!reentrancyLock);
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    modifier onlyNonZeroAddress(address toCheck) {
        require(toCheck != address(0));
        _;
    }

    modifier onlyWhitelist() {
        require(whitelist[msg.sender].alive);
        _;
    }
    
    modifier onlyMember() {
        require(members[msg.sender].alive);
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == circleAdmin);
        _;
    }

    modifier onlyModerators() {
        require(
            msg.sender == circleAdmin ||
                (members[msg.sender].alive && members[msg.sender].isModerator)
        );
        _;
    }

    modifier onlyIfCircleNotEnded() {
        require(!endOfTLCC);
        _;
    }

    modifier onlyIfCircleEnded() {
        require(endOfTLCC);
        _;
    }

    modifier onlyIfEscapeHatchActive() {
        require(escapeHatchActive);
        _;
    }

    modifier onlyIfEscapeHatchInactive() {
        require(!escapeHatchActive);
        _;
    }

    modifier onlyBIDDING_TLCC() {
        require(winnersOrder == _winnersOrder.BIDDING);
        _;
    }

    modifier onlyFromEscapeHatchEnabler() {
        require(msg.sender == ESCAPE_HATCH_ENABLER);
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/
    
    /**
    * @dev Deploy a new TLCC and initializing the contract states.
    * States cannot be changed after deploy.
    * The "circle_admin" must be a registered token bound account.
    * Only the owner of "circle_admin" or Piltonet Service Admin can deploy a new TLCC
    */
    constructor(
        address circle_admin, // token bound account
        address payment_token, // address(0) for VIC
        _paymentType payment_type,
        uint16 round_days,
        _winnersOrder winners_order,
        uint16 patience_benefit_x10000,
        uint16 creator_earnings_x10000
    ) 
        onlyRegisteredTBA(circle_admin)
	{
        require(msg.sender == getTBAOwner(circle_admin) || msg.sender == serviceAdmin(), "Error: only tba owner or service admin!");
        // require(
        //     roundPeriodInSecs_ != 0 &&
        //         startTime_ >= block.timestamp.sub(MAXIMUM_TIME_PAST_SINCE_TLCC_START_SECS) &&
        //         serviceFeeInThousandths_ <= MAX_FEE_IN_X1000 &&
        //         members_.length > 1 &&
        //         members_.length <= 256,
        //     "member count must be 1 < x <= 256"
        // );

        circleAdmin = circle_admin;
        paymentToken = payment_token;
        paymentType = payment_type;
        roundDays = round_days;
        winnersOrder = winners_order;
        creatorEarnings = creator_earnings_x10000;
        patienceBenefit = patience_benefit_x10000;

        circleStatus = _circleStatus.DEPLOYED;

        
        // roundPeriodInSecs = roundPeriodInSecs_;
        // contributionSize = contributionSize_;
        // startTime = startTime_;
        // serviceFeeInThousandths = serviceFeeInThousandths_;


        // for (uint8 i = 0; i < members_.length; i++) {
        //     addMember(members_[i]);
        // }

        // require(members[msg.sender].alive);

        emit LogTLCCDeployed(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/
    
    /**
    * @dev Setup the necessary variables of TLCC.
    * Only circle admin (tokenbound-account) can setup the circle
    * Variables can only be initialized and updated before the circle is launched.
    */
    function setupCircle(
        string memory circle_name,
        uint256 fixed_amount_x100,
        uint8 min_members,
        uint8 max_members,
        uint8 winners_number
    ) public onlyAdmin {
        require(
            circleStatus == _circleStatus.DEPLOYED ||
                circleStatus == _circleStatus.SETUPED,
            "Error: The circle is launched."
        );

        circleName = circle_name;
        minMembers = min_members;
        maxMembers = max_members;
        winnersNumber = winners_number;
        
        // To Do decimal size
        uint256 _fixedAmount = paymentToken == address(0) ? (1 ether * fixed_amount_x100) / 100 : (10**6 * fixed_amount_x100) / 100;
        contributionSize = paymentType == _paymentType.FIXED_PAY
            ? _fixedAmount
            : SafeMath.div(_fixedAmount, min_members);
        loanAmount = paymentType == _paymentType.FIXED_LOAN
            ? _fixedAmount
            : SafeMath.mul(_fixedAmount, min_members);
        
        maxRounds = uint8(maxMembers.div(winnersNumber));
        circleStatus = _circleStatus.SETUPED;
        
        // add circle admin to whitelistAddresses as default
        whitelist[msg.sender] = Whitelist({
            alive: true,
            listedBy: msg.sender,
            joined: false
        });
        whitelistAddresses.push(msg.sender);
    }

    /**
    * @dev A potential list of trusted contacts who are considered for membership in the circle.
    * Only circle admin and moderators can add to the whitelist.
    * Only trusted contacts of sender can be added to the whitelist.
    * It can only be added to the whitelist after the circle is setuped and before it is launched.
    */
    function addToWhitelist(address[] memory accounts) public 
        onlyModerators

        /** 
         * To Do
         * @dev check all accounts are sender contact
        */
        // onlyTrustedContacts(accounts)
    {
        require(
            circleStatus == _circleStatus.SETUPED,
            "Error: The circle is not setuped or is started."
        );

        for (uint8 i = 0; i < accounts.length; i++) {
            if (!whitelist[accounts[i]].alive) {
                whitelist[accounts[i]] = Whitelist({
                    alive: true,
                    listedBy: msg.sender,
                    joined: false
                });
                whitelistAddresses.push(accounts[i]);
            }
        }
    }

    function launchCircle(uint256 start_date) public onlyAdmin {
        require(
            circleStatus == _circleStatus.SETUPED,
            "Error: The circle status is not ready for launch."
        );
        require(
            whitelistAddresses.length >= CIRCLES_MIN_MEMBERS,
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
    }

    function joinCircle(uint8 selected_round) public payable
        // onlyWhitelist
        // onlyIfCircleNotEnded
        // onlyIfEscapeHatchInactive
    {
        require(
            circleStatus == _circleStatus.LAUNCHED,
            "Error: The circle status is not ready for join."
        );
        require(whitelist[msg.sender].alive, "Error: Only whitelist.");
        require(!members[msg.sender].alive, "Error: Already a member.");
        require(membersAddresses.length < maxMembers, "Error: Membership capacity is full.");

        // uint256 _balance = validateAndReturnContribution();
        
        sender_ = msg.sender;
        uint256 _balance = paymentToken == address(0) ? msg.value : IVRC25(paymentToken).balanceOf(msg.sender);
        balance_ = _balance;
        require(_balance >= contributionSize, "Error: Not enough fund.");
        // IVRC25(paymentToken).approve(address(this), contributionSize);
        if (paymentToken != address(0)) {
            require(msg.value == 0, "Error: Circle can not accept VIC.");
            IVRC25(paymentToken).transferFrom(
                msg.sender,
                address(this),
                contributionSize
            );
        }

        uint256 _totalPayments = members[sender_].totalPayments;
        members[msg.sender] = Member({
            alive: true,
            selectedRound: selected_round,
            totalPayments: SafeMath.add(_totalPayments, _balance),
            loanAmount: 0,
            credit: 0,
            paid: false,
            debtor: false,
            isModerator: false
        });
        membersAddresses.push(msg.sender);

        if (winnersOrder == _winnersOrder.FIXED)
            selectedRounds[selected_round] = msg.sender;
    }


    function addMember(
        address newMember
    ) internal onlyNonZeroAddress(newMember) {
        require(!members[newMember].alive, "already registered");

        members[newMember] = Member({
            alive: true,
            selectedRound: 0,
            totalPayments: 0,
            loanAmount: 0,
            credit: 0,
            paid: false,
            debtor: false,
            isModerator: false
        });
        membersAddresses.push(newMember);
    }

    /**
     * @dev Calculates the winner of the current round's pot, and credits her.
     * If there were no bids during the round, winner is selected semi-randomly.
     * Priority is given to non-delinquent participants.
     */
    function startRound() external onlyIfCircleNotEnded {
        uint256 roundStartTime = SafeMath.add(
            startTime,
            (SafeMath.mul(currentRound - 1, roundPeriodInSecs))
        );
        require(
            block.timestamp >= roundStartTime,
            "too early to start a new round."
        );

        if (currentRound != 1) {
            cleanUpPreviousRound();
        }
        if (currentRound < membersAddresses.length) {
            lowestBid = 0;
            winnerAddress = address(0);
            currentRound++;
            emit LogStartOfRound(currentRound);
        } else {
            endOfTLCC = true;
            emit LogEndOfTLCC();
        }
    }

    /**
     * @dev determine the winner based on the bid, or if no bids were place, find a random winner and credit the
     * member with winnings
     */
    function cleanUpPreviousRound() internal {
        // for pre-ordered TLCC, pick the next person in the list (delinquent or not)
        if (winnersOrder == _winnersOrder.FIXED) {
            winnerAddress = membersAddresses[currentRound - 1];
        } else {
            // We keep the unpaid participants at positions [0..num_participants - current_round) so that we can uniformly select
            // among them (if we didn't do that and there were a few consecutive paid participants, we'll be more likely to select the
            // next unpaid member).
            swapWinner();
        }

        creditWinner();
        recalculateTotalFees();
    }

    /**
     * @dev update the winner's credit with the winning Bid amount or the default PotSize if there were no bid and
     * roundDiscount is added to totalDiscounts
     */
    function creditWinner() internal {
        if (lowestBid == 0) {
            lowestBid = potSize();
        }
        uint256 currentRoundTotalDiscounts = removeFees(potSize() - lowestBid);
        uint256 roundDiscount = currentRoundTotalDiscounts /
            membersAddresses.length;
        totalDiscounts += currentRoundTotalDiscounts;
        members[winnerAddress].credit += removeFees(lowestBid);
        members[winnerAddress].paid = true;
        emit LogRoundFundsReleased(
            winnerAddress,
            lowestBid,
            roundDiscount,
            currentRound
        );
    }

    /**
     * @dev we choose a winner base current timestamp, giving priority to members in good standing.
     * this is a non-Issue because by nature of TLCC, each member can only win once
     * @return uint256
     */
    function findSemiRandomWinner(
        uint16 numUnpaidParticipants
    ) internal returns (uint256) {
        address delinquentWinner = address(0);
        uint256 winnerIndex;
        // There was no bid in this round. Find an unpaid address for this epoch.
        // Give priority to members in good standing (not delinquent).
        // Note this randomness does not require high security, that's why we feel ok with using the block's timestamp.
        // Everyone will be paid out eventually.
        uint256 semi_random = block.timestamp % numUnpaidParticipants;
        for (uint16 i = 0; i < numUnpaidParticipants; i++) {
            uint256 index = (semi_random + i) % numUnpaidParticipants;
            address candidate = membersAddresses[index];
            if (!members[candidate].paid) {
                winnerIndex = index;
                if (userTotalCredit(candidate) >= requiredContribution()) {
                    // We found a non-delinquent winner.
                    winnerAddress = candidate;
                    break;
                }
                delinquentWinner = candidate;
            }
        }
        if (winnerAddress == address(0)) {
            // we did not find any non-delinquent winner.
            // Perform some basic sanity checks.
            assert(
                delinquentWinner != address(0) &&
                    !members[delinquentWinner].paid
            );
            winnerAddress = delinquentWinner;
            // Set the flag to true so we know this member cannot withdraw until debt has been paid.
            members[winnerAddress].debtor = true;
        }
        // Set lowestBid to the right value since there was no winning bid.
        lowestBid = potSize();
        return winnerIndex;
    }

    /**
     * @dev Recalculates that total fees that should be allocated in the contract.
     */
    function recalculateTotalFees() internal {
        // Start with the max theoretical fees if no one was delinquent, and
        // reduce funds not actually contributed because of delinquencies.
        uint256 grossTotalFees = SafeMath.mul(
            requiredContribution(),
            membersAddresses.length
        );

        for (uint16 j = 0; j < membersAddresses.length; j++) {
            Member memory member = members[membersAddresses[j]];
            uint256 credit = userTotalCredit(membersAddresses[j]);
            uint256 debit = requiredContribution();
            if (member.debtor) {
                // As a delinquent member won, we'll reduce the funds subject to fees by the default pot they must have won (since
                // they could not bid), to correctly calculate their delinquency.
                debit = SafeMath.add(debit, removeFees(potSize()));
            }
            if (credit < debit) {
                grossTotalFees = SafeMath.sub(grossTotalFees, (debit - credit));
            }
        }

        totalFees =
            SafeMath.mul(grossTotalFees, serviceFeeInThousandths) /
            1000;
    }

    /**
     * @dev Swaps membersAddresses[winnerIndex] with membersAddresses[indexToSwap]. However,
     * if winner was selected through a bid, winnerIndex was not set, and we find it first.
     */
    function swapWinner() internal {
        uint256 winnerIndex;
        uint16 numUnpaidParticipants = uint16(membersAddresses.length) -
            (currentRound - 1);
        uint16 indexToSwap = numUnpaidParticipants - 1;

        if (winnerAddress == address(0)) {
            // there are no bids this round, so find a random winner
            winnerIndex = findSemiRandomWinner(numUnpaidParticipants);
        } else {
            // Since winner was selected through a bid, we were not able to set winnerIndex, so search
            // for the winner among the unpaid participants.
            for (uint16 i = 0; i <= indexToSwap; i++) {
                if (membersAddresses[i] == winnerAddress) {
                    winnerIndex = i;
                    break;
                }
            }
        }
        // We now want to swap winnerIndex with indexToSwap, but we already know membersAddresses[winnerIndex] == winnerAddress.
        membersAddresses[winnerIndex] = membersAddresses[indexToSwap];
        membersAddresses[indexToSwap] = winnerAddress;
    }

    /**
     * @dev Calculates the specified amount net amount after fees.
     * @return uint256
     */
    function removeFees(
        uint256 amount
    ) internal view virtual returns (uint256) {
        // First multiply to reduce roundoff errors.
        return SafeMath.mul(amount, (1000 - serviceFeeInThousandths)) / 1000;
    }

    /**
     * @dev Validates a non-zero contribution from msg.sender and returns
     * the amount.
     * @return uint256
     */
    function validateAndReturnContribution() internal returns (uint256) {
        // dontMakePublic
        bool isPaymentByVIC = (paymentToken == address(0));
        require(
            isPaymentByVIC || msg.value <= 0,
            "Error: TLCC can not accept VIC."
        );

        uint256 value = (
            isPaymentByVIC
                ? msg.value
                : IVRC25(paymentToken).allowance(msg.sender, address(this))
        );
        require(value != 0);
        require(value >= contributionSize, "Error: Not enough fund.");

        if (isPaymentByVIC) {
            return value;
        }

        // bool vrc25Transfer = IVRC25(paymentToken).transferFrom(msg.sender, address(this), value);
        bool vrc25Transfer = IVRC25(paymentToken).transfer(address(this), value);
        // require(vrc25Transfer, "Error: VRC25 transfer failed.");
        require(vrc25Transfer);
        return value;
    }

    /**
     * @dev Processes a periodic contribution. msg.sender must be one of the participants and will thus
     * identify the contributor.
     *
     * Any excess funds are withdrawable through withdraw() without fee.
     */
    function contribute()
        external
        payable
        onlyMember
        onlyIfCircleNotEnded
        onlyIfEscapeHatchInactive
    {
        Member storage member = members[msg.sender];
        uint256 value = validateAndReturnContribution();
        member.credit = SafeMath.add(member.credit, value);
        if (member.debtor) {
            // Check if member comes out of debt. We know they won an entire pot as they could not bid,
            // so we check whether their credit w/o that winning is non-delinquent.
            // check that credit must defaultPot (when debt is set to true, defaultPot was added to credit as winnings) +
            // currentRound in order to be out of debt
            if (
                SafeMath.sub(
                    userTotalCredit(msg.sender),
                    removeFees(potSize())
                ) >= requiredContribution()
            ) {
                member.debtor = false;
            }
        }

        emit LogContributionMade(msg.sender, value, currentRound);
    }

    /**
     * @dev Registers a bid from msg.sender. Participant should call this method
     * only if all of the following holds for her:
     * + Never won a round.
     * + Is in good standing (i.e. actual contributions, including this round's,
     *   plus any past earned discounts are together greater than required contributions).
     * + New bid is lower than the lowest bid so far.
     * @param bidAmount The bid amount to place in Wei
     */
    function bid(
        uint256 bidAmount
    )
        public
        onlyMember
        onlyIfCircleNotEnded
        onlyIfEscapeHatchInactive
        onlyBIDDING_TLCC
    {
        require(
            !members[msg.sender].paid &&
                currentRound != 0 && // TLCC hasn't started yet
                // participant not in good standing
                userTotalCredit(msg.sender) >= requiredContribution() &&
                // bid is less than minimum allowed
                bidAmount >=
                SafeMath.mul(potSize(), MIN_DISTRIBUTION_PERCENT) / 100
        );

        // If winnerAddress is 0, this is the first bid, hence allow full pot.
        // Otherwise, make sure bid is low enough compared to previous bid.
        uint256 maxAllowedBid = winnerAddress == address(0)
            ? potSize()
            : SafeMath.mul(lowestBid, MAX_NEXT_BID_RATIO) / 100;
        if (bidAmount > maxAllowedBid) {
            // We don't throw as this may be hard for the frontend to predict on the
            // one hand because someone else might have bid at the same time,
            // and we'd like to avoid wasting the caller's gas.
            emit LogUnsuccessfulBid(
                msg.sender,
                bidAmount,
                lowestBid,
                currentRound
            );
            return;
        }
        if (winnerAddress != address(0)) {
            emit LogBidSurpassed(lowestBid, winnerAddress, currentRound);
        }

        lowestBid = bidAmount;
        winnerAddress = msg.sender;
        emit LogNewLowestBid(lowestBid, winnerAddress, currentRound);
    }

    // Sends funds (either VIC or CUSD) to msg.sender. Returns whether successful.
    function sendFundsToMsgSender(uint256 value) internal returns (bool) {
        bool isPaymentByVIC = (paymentToken == address(0));
        if (isPaymentByVIC) {
            return payable(msg.sender).send(value);
        }
        return IVRC25(paymentToken).transfer(msg.sender, value);
    }

    /**
     * @dev Withdraws available funds for msg.sender.
     * @return success False if the transfer fails
     */
    function withdraw()
        external
        onlyMember
        onlyIfEscapeHatchInactive
        nonReentrant
        returns (bool success)
    {
        require(
            !members[msg.sender].debtor || endOfTLCC,
            "delinquent winners need to first pay their debt"
        );

        uint256 totalCredit = userTotalCredit(msg.sender);

        uint256 totalDebit = members[msg.sender].debtor
            ? removeFees(potSize()) // this must be end of circle
            : requiredContribution();
        require(totalDebit < totalCredit, "nothing to withdraw");

        uint256 amountToWithdraw = SafeMath.sub(totalCredit, totalDebit);
        uint256 amountAvailable = SafeMath.sub(getBalance(), totalFees);

        if (amountAvailable < amountToWithdraw) {
            // This may happen if some participants are delinquent.
            emit LogCannotWithdrawFully(
                msg.sender,
                amountToWithdraw,
                currentRound
            );
            amountToWithdraw = amountAvailable;
        }
        members[msg.sender].credit -= amountToWithdraw;
        if (!sendFundsToMsgSender(amountToWithdraw)) {
            // if the send() fails, restore the allowance
            // No need to call throw here, just reset the amount owing. This may happen
            // for nonmalicious reasons, e.g. the receiving contract running out of gas.
            members[msg.sender].credit += amountToWithdraw;
            return false;
        }
        emit LogFundsWithdrawal(msg.sender, amountToWithdraw, currentRound);
        return true;
    }

    /**
     * @dev Returns how much a member can withdraw (positive return value),
     * or how much they need to contribute to be in good standing (negative return value)
     * @return int256
     */
    function getParticipantBalance(
        address member
    ) public view onlyMember returns (int256) {
        int256 totalCredit = int256(userTotalCredit(member));

        // if circle have ended, we don't need to subtract as totalDebit should equal to default winnings
        if (members[member].debtor && !endOfTLCC) {
            totalCredit -= int256(removeFees(potSize()));
        }
        int256 totalDebit = int256(requiredContribution());

        return totalCredit - totalDebit;
    }

    /**
     * @dev Returns the amount of funds this contract holds excluding fees. This is
     * the amount withdrawable by participants.
     * @return uint256
     */
    function getContractNetBalance() public view returns (uint256) {
        return SafeMath.sub(getBalance(), totalFees);
    }

    /**
     * @dev Returns the balance of this contract, in VIC or CUSD.
     * @return uint256
     */
    function getBalance() internal view virtual returns (uint256) {
        bool isPaymentByVIC = (paymentToken == address(0));

        return
            isPaymentByVIC
                ? address(this).balance
                : IVRC25(paymentToken).balanceOf(address(this));
    }

    /**
     * @dev Allows the admin to retrieve any surplus funds, one roundPeriodInSecs after
     * the end of the TLCC. Note this does not retrieve the admin's fees, which should
     * be retireved by calling endOfTLCCRetrieveFees.
     *
     * Note that startRound() must be called first after the last round, as it
     * does the bookeeping of that round.
     */
    function endOfTLCCRetrieveSurplus()
        external
        onlyAdmin
        onlyIfCircleEnded
    {
        uint256 roscaCollectionTime = SafeMath.add(
            startTime,
            SafeMath.mul((membersAddresses.length + 1), roundPeriodInSecs)
        );
        require(
            block.timestamp >= roscaCollectionTime &&
                !adminSurplusCollected
        );

        adminSurplusCollected = true;
        uint256 amountToCollect = SafeMath.sub(getBalance(), totalFees);
        if (!sendFundsToMsgSender(amountToCollect)) {
            // if the send() fails, restore the flag
            // No need to call throw here, just reset the amount owing. This may happen
            // for nonmalicious reasons, e.g. the receiving contract running out of gas.
            adminSurplusCollected = false;
        } else {
            emit LogForepersonSurplusWithdrawal(amountToCollect);
        }
    }

    /**
     * @dev Allows the admin to extract the fees in the contract. Can be called
     * after the end of the TLCC.
     *
     * Note that startRound() must be called first after the last round, as it
     * does the bookeeping of that round.
     */
    function endOfTLCCRetrieveFees()
        external
        onlyAdmin
        onlyIfCircleEnded
    {
        uint256 tempTotalFees = totalFees; // prevent re-entry.
        totalFees = 0;
        if (!sendFundsToMsgSender(tempTotalFees)) {
            // if the send() fails, restore totalFees
            // No need to call throw here, just reset the amount owing. This may happen
            // for nonmalicious reasons, e.g. the receiving contract running out of gas.
            totalFees = tempTotalFees;
        } else {
            emit LogFeesWithdrawal(tempTotalFees);
        }
    }

    /**
     * @dev Allows the Escape Hatch Enabler (controlled by Piltonet) to enable the Escape Hatch in case of
     * emergency (e.g. a major vulnerability found in the contract).
     */
    function enableEscapeHatch() external onlyFromEscapeHatchEnabler {
        escapeHatchEnabled = true;
        emit LogEscapeHatchEnabled();
    }

    /**
     * @dev Allows the admin to active the Escape Hatch after the Enabled enabled it. This will freeze all
     * contributions and withdrawals, and allow the admin to retrieve all funds into their own account,
     * to be dispersed offline to the other participants.
     */
    function activateEscapeHatch() external onlyAdmin {
        require(escapeHatchEnabled);

        escapeHatchActive = true;
        emit LogEscapeHatchActivated();
    }

    /**
     * @dev Can only be called by the admin after an escape hatch is activated,
     * this sends all the funds to the admin by selfdestructing this contract.
     */
    function emergencyWithdrawal()
        external
        onlyAdmin
        onlyIfEscapeHatchActive
    {
        emit LogEmergencyWithdrawalPerformed(getBalance(), currentRound);
        bool fundsTransferSuccess = false;
        // Send everything, including potential fees, to admin to disperse offline to participants.
        bool isPaymentByVIC = (paymentToken == address(0));
        if (!isPaymentByVIC) {
            uint256 balance = IVRC25(paymentToken).balanceOf(address(this));
            fundsTransferSuccess = IVRC25(paymentToken).transfer(
                circleAdmin,
                balance
            );
        }

        // if (fundsTransferSuccess || isPaymentByVIC) {
        //   selfdestruct(admin);
        // }
    }

    ////////////////////
    // HELPER FUNCTIONS
    ////////////////////

    /**
     * @dev calculates the member's discount amount from the total discount
     * @return uint256
     */
    function userTotalCredit(
        address memberAddress
    ) internal view virtual returns (uint256) {
        uint256 userDiscount = totalDiscounts / membersAddresses.length;

        return SafeMath.add(members[memberAddress].credit, userDiscount);
    }

    /**
     * @dev calculates the default amount member can win in a round
     * @return uint256
     */
    function potSize() internal view virtual returns (uint256) {
        return SafeMath.mul(contributionSize, membersAddresses.length);
    }

    /**
     * @dev calculates the require amount of contribution for member to be in good standing
     * @return uint256
     */
    function requiredContribution() internal view virtual returns (uint256) {
        return SafeMath.mul(contributionSize, currentRound);
    }

    // Internal
    // --------------------------------------------------------------------------------
    

    function roundDueDate(uint8 round_index) internal virtual returns (uint256) {
        return
            startDate > 0 && round_index < maxRounds
                ? startDate.add(roundDays.mul(round_index).mul(60 * 60 * 24))
                : 0;
    }

}
