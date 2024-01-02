// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "vrc25/contracts/interfaces/IVRC25.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/SafeMath.sol";

/// @title Trusted Lending Circle Contract - TLCC
/// @notice TLCC on Viction
/// @dev Supports VIC and CUSD (any VRC25 tokens)
/*///////////////////////////////////////////////////////////////
A TLCC (Trusted Lending Circle Contract) is an agreement between trusted
family and friends to contribute regularly to a pool of funds and give it
all to one or more members (termed "Winner") until everyone in the group
gets their chance.
The person who deploys the TLCC is known as the contract owner (termed "Admin").
Admin specifies the main parameters of the circle while deploying the TLCC.
Such as payment token, length of each period, etc.
//////////////////////////////////////////////////////////////*/
contract TLCC is Ownable(msg.sender) {
    using SafeMath for *;
	
    uint16 public constant TLCC_VERSION = 2;

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

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    event LogContributionMade(
        address indexed user,
        uint256 amount,
        uint256 currentRound
    );
    event LogStartOfRound(uint256 currentRound);
    event LogBidSurpassed(
        uint256 prevBid,
        address indexed prevWinnerAddress,
        uint256 currentRound
    );
    event LogNewLowestBid(
        uint256 bid,
        address indexed winnerAddress,
        uint256 currentRound
    );
    event LogRoundFundsReleased(
        address indexed winnerAddress,
        uint256 amount,
        uint256 roundDiscount,
        uint256 currentRound
    );
    event LogFundsWithdrawal(
        address indexed user,
        uint256 amount,
        uint256 currentRound
    );
    // Fired when withdrawer is entitled for a larger amount than the contract
    // actually holds (excluding fees). A LogFundsWithdrawal will follow
    // this event with the actual amount released, if send() is successful.
    event LogCannotWithdrawFully(
        address indexed user,
        uint256 creditAmount,
        uint256 currentRound
    );
    event LogUnsuccessfulBid(
        address indexed bidder,
        uint256 bid,
        uint256 lowestBid,
        uint256 currentRound
    );
    event LogEndOfTLCC();
    event LogForepersonSurplusWithdrawal(uint256 amount);
    event LogFeesWithdrawal(uint256 amount);

    // Escape hatch related events.
    event LogEscapeHatchEnabled();
    event LogEscapeHatchActivated();
    event LogEmergencyWithdrawalPerformed(
        uint256 fundsDispersed,
        uint256 currentRound
    );

    /*///////////////////////////////////////////////////////////////
                            States
    //////////////////////////////////////////////////////////////*/
    // TLCC parameters
    uint256 internal roundPeriodInSecs;
    uint16 internal serviceFeeInThousandths;
    uint16 public currentRound = 1; // circle is started the moment it is created
    address internal admin;
    uint128 internal contributionSize;
    uint256 internal startTime;
    
    
    address public paymentToken; // public - allow easy verification of token contract.

    // Payment Type
    // 0 : Loan amount will be based on the number of members and other rules. (FIXED_PAY)
    // 1 : Contribution amount will be based on the number of members and other rules. (FIXED_LOAN)
    enum _paymentType {
        FIXED_PAY,
        FIXED_LOAN
    }
    _paymentType paymentType;

    uint16 internal roundDays;

    // Winners Order
    // 0 : Winner(s) is/are chosen at random (RANDOM)
    // 1 : Winner(s) is/are selected through a predetermined ordered list (FIXED)
    // 2 : Lowest bidder wins (BIDDING)
    enum _winnersOrder {
        RANDOM,
        FIXED,
        BIDDING
    }
    _winnersOrder winnersOrder;

    uint16 internal creatorEarnings; // Multiplied by Ten Thousand Times
    uint16 internal patienceBenefit; // Multiplied by Ten Thousand Times


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

    struct User {
        uint256 credit; // amount of funds user has contributed - winnings (not including discounts) so far
        bool debt; // true if user won the pot while not in good standing and is still not in good standing
        bool paid; // yes if the member had won a Round
        bool alive; // needed to check if a member is indeed a member
    }

    mapping(address => User) internal members;
    address[] public membersAddresses; // for iterating through members' addresses

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

    modifier onlyFromMember() {
        require(members[msg.sender].alive);
        _;
    }

    modifier onlyFromForeperson() {
        require(msg.sender == admin);
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
    constructor(
        address payment_token, // address(0) for VIC
        _paymentType payment_type,
        uint16 round_days,
        _winnersOrder winners_order,
        uint16 patience_benefit_x10000,
        uint16 creator_earnings_x10000
    ) 
	{
        // require(
        //     roundPeriodInSecs_ != 0 &&
        //         startTime_ >= block.timestamp.sub(MAXIMUM_TIME_PAST_SINCE_TLCC_START_SECS) &&
        //         serviceFeeInThousandths_ <= MAX_FEE_IN_X1000 &&
        //         members_.length > 1 &&
        //         members_.length <= 256,
        //     "member count must be 1 < x <= 256"
        // );

        paymentToken = payment_token;
        paymentType = payment_type;
        roundDays = round_days;
        winnersOrder = winners_order;
        creatorEarnings = creator_earnings_x10000;
        patienceBenefit = patience_benefit_x10000;
        
        // roundPeriodInSecs = roundPeriodInSecs_;
        // contributionSize = contributionSize_;
        // startTime = startTime_;
        // serviceFeeInThousandths = serviceFeeInThousandths_;

        admin = msg.sender;

        // for (uint8 i = 0; i < members_.length; i++) {
        //     addMember(members_[i]);
        // }

        // require(members[msg.sender].alive);

        emit LogStartOfRound(currentRound);
    }

    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/
    function addMember(
        address newMember
    ) internal onlyNonZeroAddress(newMember) {
        require(!members[newMember].alive, "already registered");

        members[newMember] = User({
            paid: false,
            credit: 0,
            alive: true,
            debt: false
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
     * user with winnings
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
            // Set the flag to true so we know this user cannot withdraw until debt has been paid.
            members[winnerAddress].debt = true;
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
            User memory member = members[membersAddresses[j]];
            uint256 credit = userTotalCredit(membersAddresses[j]);
            uint256 debit = requiredContribution();
            if (member.debt) {
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
            "token TLCCs should not accept VIC"
        );

        uint256 value = (
            isPaymentByVIC
                ? msg.value
                : IVRC25(paymentToken).allowance(msg.sender, address(this))
        );
        require(value != 0);

        if (isPaymentByVIC) {
            return value;
        }
        require(
            IVRC25(paymentToken).transferFrom(msg.sender, address(this), value)
        );
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
        onlyFromMember
        onlyIfCircleNotEnded
        onlyIfEscapeHatchInactive
    {
        User storage member = members[msg.sender];
        uint256 value = validateAndReturnContribution();
        member.credit = SafeMath.add(member.credit, value);
        if (member.debt) {
            // Check if user comes out of debt. We know they won an entire pot as they could not bid,
            // so we check whether their credit w/o that winning is non-delinquent.
            // check that credit must defaultPot (when debt is set to true, defaultPot was added to credit as winnings) +
            // currentRound in order to be out of debt
            if (
                SafeMath.sub(
                    userTotalCredit(msg.sender),
                    removeFees(potSize())
                ) >= requiredContribution()
            ) {
                member.debt = false;
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
        onlyFromMember
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
        onlyFromMember
        onlyIfEscapeHatchInactive
        nonReentrant
        returns (bool success)
    {
        require(
            !members[msg.sender].debt || endOfTLCC,
            "delinquent winners need to first pay their debt"
        );

        uint256 totalCredit = userTotalCredit(msg.sender);

        uint256 totalDebit = members[msg.sender].debt
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
     * @dev Returns how much a user can withdraw (positive return value),
     * or how much they need to contribute to be in good standing (negative return value)
     * @return int256
     */
    function getParticipantBalance(
        address user
    ) public view onlyFromMember returns (int256) {
        int256 totalCredit = int256(userTotalCredit(user));

        // if circle have ended, we don't need to subtract as totalDebit should equal to default winnings
        if (members[user].debt && !endOfTLCC) {
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
        onlyFromForeperson
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
        onlyFromForeperson
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
    function activateEscapeHatch() external onlyFromForeperson {
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
        onlyFromForeperson
        onlyIfEscapeHatchActive
    {
        emit LogEmergencyWithdrawalPerformed(getBalance(), currentRound);
        bool fundsTransferSuccess = false;
        // Send everything, including potential fees, to admin to disperse offline to participants.
        bool isPaymentByVIC = (paymentToken == address(0));
        if (!isPaymentByVIC) {
            uint256 balance = IVRC25(paymentToken).balanceOf(address(this));
            fundsTransferSuccess = IVRC25(paymentToken).transfer(
                admin,
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
     * @dev calculates the user's discount amount from the total discount
     * @return uint256
     */
    function userTotalCredit(
        address memberAddress
    ) internal view virtual returns (uint256) {
        uint256 userDiscount = totalDiscounts / membersAddresses.length;

        return SafeMath.add(members[memberAddress].credit, userDiscount);
    }

    /**
     * @dev calculates the default amount user can win in a round
     * @return uint256
     */
    function potSize() internal view virtual returns (uint256) {
        return SafeMath.mul(contributionSize, membersAddresses.length);
    }

    /**
     * @dev calculates the require amount of contribution for user to be in good standing
     * @return uint256
     */
    function requiredContribution() internal view virtual returns (uint256) {
        return SafeMath.mul(contributionSize, currentRound);
    }
}
