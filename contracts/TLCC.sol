// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "vrc25/contracts/interfaces/IVRC25.sol";
import "./access/ServiceAdmin.sol";
import "./access/RegisteredTBA.sol";
import "./access/TrustedContact.sol";
import "./access/AcceptedTokens.sol";
import "./interfaces/ITLCC.sol";
import "./constants/CTLCC.sol";
import "./utils/SafeMath.sol";
import "./utils/Utils.sol";

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
contract TLCC is ITLCC, CTLCC, ServiceAdmin, RegisteredTBA, TrustedContact, AcceptedTokens {
    using SafeMath for *;
	
    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    address internal circleAdmin;
    address public paymentToken; // public - allow easy verification of token contract.

    uint16 internal roundDays;

    // Winners Order
    enum WinnersOrder {
        RANDOM, // 0 : Winner(s) is/are chosen at random (RANDOM)
        FIXED, // 1 : Winner(s) is/are selected through a predetermined ordered list (FIXED)
        BIDDING // 2 : Lowest bidder wins (BIDDING)
    }
    WinnersOrder winnersOrder;

    uint16 internal creatorEarnings; // Multiplied by Ten Thousand Times
    uint16 internal patienceBenefit; // Multiplied by Ten Thousand Times

    // Circle Status
    enum CircleStatus {
        DEPLOYED,
        LAUNCHED,
        STARTED,
        PAUSED,
        STOPED,
        COMPLETED
    }
    CircleStatus public circleStatus; // To Do internal - public temp, for easy test

    // TLCC parameters
    string public circleName; // To Do internal - public temp, for easy test
    uint256 public roundPayments; // To Do internal - public temp, for easy test
    uint256 public loanAmount; // To Do internal - public temp, for easy test
    uint8 private circleSize;

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

    modifier onlyCircleAdmin() {
        require(msg.sender == circleAdmin);
        _;
    }

    modifier onlyCircleModerators() {
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
        require(winnersOrder == WinnersOrder.BIDDING);
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
        string memory circle_name,
        uint8 circle_size,
        uint16 round_days,
        string memory round_payments,
        WinnersOrder winners_order,
        uint16 patience_benefit_x10000,
        uint16 creator_earnings_x10000
    ) 
        onlyAcceptedTokens(payment_token)
	{
        require(
            msg.sender == serviceAdmin() || msg.sender == getTBAOwner(circle_admin),
            "Error: only tba owner or service admin!"
        );
        require(
            circle_size >= CIRCLES_MIN_MEMBERS &&
            circle_size <= CIRCLES_MAX_MEMBERS,
            "Error: The circle size is out of range."
        );
        require(
            round_days != 0,
            "Error: The round days must be greater than 0."
        );
        // check round payments amount
        (uint256 minRoundPay, uint256 maxRoundPay, ) = getRoundPayments(payment_token);
        uint256 _roundPayments = Utils.stringToUint(round_payments);
        require(
            _roundPayments >= minRoundPay &&
            _roundPayments <= maxRoundPay,
            "Error: The round payments is out of range."
        );
        require(
            patience_benefit_x10000 == 0 || winners_order != WinnersOrder.BIDDING,
            "Error: The patience benefit is not available in bidding mode."
        );
        require(
            patience_benefit_x10000 <= CIRCLES_MAX_PATIENCE_BENEFIT_X10000,
            "Error: The patience benefit is out of range."
        );
        require(
            creator_earnings_x10000 <= CIRCLES_MAX_CREATOR_EARNINGS_X10000,
            "Error: The creator earnings is out of range."
        );

        // update variables
        circleAdmin = circle_admin;
        paymentToken = payment_token;
        circleName = circle_name;
        circleSize = circle_size;
        roundDays = round_days;
        roundPayments = Utils.stringToUint(round_payments);
        loanAmount = SafeMath.mul(roundPayments, circleSize);
        winnersOrder = winners_order;
        patienceBenefit = patience_benefit_x10000;
        creatorEarnings = creator_earnings_x10000;

        circleStatus = CircleStatus.DEPLOYED;

        // add circle admin to whitelist as default
        whitelist[circleAdmin] = Whitelist({
            alive: true,
            listedBy: circleAdmin,
            joined: false
        });
        whitelistAddresses.push(circleAdmin);

        emit LogTLCCDeployed(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/
    
    /**
    * @dev Setup/Update the necessary variables of TLCC.
    * Only circle admin (tokenbound-account) can setup the circle
    * Variables can only be initialized and updated before the circle is launched.
    */
    function updateCircle(
        string memory circle_name,
        string memory round_payments,
        uint8 circle_size,
        uint8 extra_members,
        uint8 round_winners
    ) public onlyCircleAdmin {
        // check circle status before setup or update
        require(
            circleStatus == CircleStatus.DEPLOYED,
            "Error: It is not possible to update the circle."
        );
        
        // check round payments amount
        uint256 _fixedAmount = Utils.stringToUint(round_payments);
        uint256 _roundPayments = _fixedAmount;
        (uint256 minRoundPay, uint256 maxRoundPay, ) = getRoundPayments(paymentToken);
        require(
            _roundPayments >= minRoundPay &&
            _roundPayments <= maxRoundPay,
            "Error: The round payments is out of range."
        );

        // check member counts & winners number
        require(
            circle_size >= CIRCLES_MIN_MEMBERS &&
            circle_size <= CIRCLES_MAX_MEMBERS,
            "Error: The number of members is out of range."
        );
        require(
            extra_members <= circle_size * 2 / 10,
            "Error: The number of extra members is more than 20% of the circle size."
        );
        require(
            SafeMath.div(circle_size, round_winners) >= CIRCLES_MIN_MEMBERS,
            "Error: The number of winners is too big."
        );

        // update variables
        circleName = circle_name;
        roundPayments = _roundPayments;
        loanAmount = SafeMath.mul(_roundPayments, circle_size);
        circleSize = circle_size;
        
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
        onlyCircleModerators

        /** 
         * To Do
         * @dev check all accounts are sender contact
        */
        // onlyTrustedContacts(accounts)
    {
        require(
            circleStatus == CircleStatus.LAUNCHED,
            "Error: Unable to add to the whitelist of this circle."
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

    function launchCircle(uint256 start_date) public onlyCircleAdmin {
        require(
            circleStatus == CircleStatus.DEPLOYED,
            "Error: The circle status is not ready for the launch."
        );
        require(
            whitelistAddresses.length >= CIRCLES_MIN_MEMBERS,
            "Error: The number of whitelisted accounts is insufficient for the launch."
        );
        require(
            // Start date must be a 10-digit number
            start_date > (10 ** 9) && start_date < (10 ** 10)
            // and at least one day later
            && SafeMath.div(start_date, 60 * 60 * 24) > SafeMath.div(block.timestamp, 60 * 60 * 24),
            "Error: The start date is out of range."
        );

        startDate = start_date.div(60 * 60 * 24).mul(60 * 60 * 24);
        circleStatus = CircleStatus.LAUNCHED;
    }

    function joinCircle(uint8 selected_round) public payable
        // onlyWhitelist
        // onlyIfCircleNotEnded
        // onlyIfEscapeHatchInactive
    {
        require(
            circleStatus == CircleStatus.LAUNCHED,
            "Error: The circle status is not ready for join."
        );
        require(whitelist[msg.sender].alive, "Error: Only whitelist.");
        require(!members[msg.sender].alive, "Error: Already a member.");
        require(membersAddresses.length < circleSize, "Error: Membership capacity is full.");

        // uint256 _balance = validateAndReturnContribution();
        
        uint256 _balance = paymentToken == address(0) ? msg.value : IVRC25(paymentToken).balanceOf(msg.sender);
        require(_balance >= roundPayments, "Error: Not enough fund.");
        // IVRC25(paymentToken).approve(address(this), roundPayments);
        if (paymentToken != address(0)) {
            require(msg.value == 0, "Error: Circle can not accept VIC.");
            IVRC25(paymentToken).transferFrom(
                msg.sender,
                address(this),
                roundPayments
            );
        }

        uint256 _totalPayments = members[msg.sender].totalPayments;
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

        if (winnersOrder == WinnersOrder.FIXED)
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
        if (winnersOrder == WinnersOrder.FIXED) {
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
        require(value >= roundPayments, "Error: Not enough fund.");

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
        onlyCircleAdmin
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
        onlyCircleAdmin
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
    function activateEscapeHatch() external onlyCircleAdmin {
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
        onlyCircleAdmin
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
        return SafeMath.mul(roundPayments, membersAddresses.length);
    }

    /**
     * @dev calculates the require amount of contribution for member to be in good standing
     * @return uint256
     */
    function requiredContribution() internal view virtual returns (uint256) {
        return SafeMath.mul(roundPayments, currentRound);
    }

    // Internal
    // --------------------------------------------------------------------------------
    function roundDueDate(uint8 round_index) internal virtual returns (uint256) {
        return
            startDate > 0 && round_index < circleSize
                ? startDate.add(roundDays.mul(round_index).mul(60 * 60 * 24))
                : 0;
    }

    // public
    function getTLCCConstants() public view returns (string memory) {
        string memory _paymentTokens;
        for (uint256 i = 0; i < PAYMENT_TOKENS.length; i++) {
            if(i > 0) _paymentTokens = string(abi.encodePacked(_paymentTokens, ","));
            _paymentTokens = string(abi.encodePacked(
                _paymentTokens,
                '"', Utils.addressToString(PAYMENT_TOKENS[i]),
                '" : { "TOKEN_SYMBOL": "', TOKEN_SYMBOLS[i],
                '", "TOKEN_DECIMALS": ', Strings.toString(TOKEN_DECIMALS[i]),
                ', "MIN_ROUND_PAY": ', Strings.toString(MIN_ROUND_PAY[i]),
                ', "MAX_ROUND_PAY": ', Strings.toString(MAX_ROUND_PAY[i]), ' }'
            ));
        }
        return string(abi.encodePacked(
            '{ "TLCC_VERSION": ', Strings.toString(TLCC_VERSION),
            ', "PILTONET_SERVICE_ADMIN": "', Utils.addressToString(PILTONET_SERVICE_ADMIN),
            '", "CIRCLES_PAYMENT_TOKENS": {', _paymentTokens,
            '}, "CIRCLES_MIN_MEMBERS": ', Strings.toString(CIRCLES_MIN_MEMBERS),
            ', "CIRCLES_MAX_MEMBERS": ', Strings.toString(CIRCLES_MAX_MEMBERS),
            ', "CIRCLES_SERVICE_CHARGE_X10000": ', Strings.toString(CIRCLES_SERVICE_CHARGE_X10000),
            ', "CIRCLES_MAX_CREATOR_EARNINGS_X10000": ', Strings.toString(CIRCLES_MAX_CREATOR_EARNINGS_X10000),
            ', "CIRCLES_MAX_PATIENCE_BENEFIT_X10000": ', Strings.toString(CIRCLES_MAX_PATIENCE_BENEFIT_X10000), ' }'
        ));
    }
}
