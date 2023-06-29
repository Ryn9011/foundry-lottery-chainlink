// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License_Identifier: MIT

pragma solidity ^0.8.18;

// need to install smart contract kit
//forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A Sample raflle contract
 * @author Ryan Jennings
 * @notice This contract is a sample raffle contract
 * @dev Implents Chainlink VRF
 */
contract Raffle is VRFConsumerBaseV2 {
    error Raffle__TransferFailed();
    error Raffle__NotEnoughEthToEnterRaffle();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );
    error Raffle__RaffleNotOpen();

    /** Type Decarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    // good practice to make state variables private and create getters as needed
    // immutable saves gas
    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    // reason for array over mapping we need to pick a winner and not possible to loop through mapping of unknown size
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    // create helper config so deploy script can pass in the values for the particular chain we want to use
    // in order to use a inherited functions constructor we need to pass it in our constructor ourselves
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,       
        uint32 callbackGasLimit      
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    // external can be used instead of public to save gas as not called internally
    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) {
            revert();
        }
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the chainlink automation nodes will call to see if it's time to perform an upkeep
     * the following should be true for this to return true:
     * 1. the time interval has passed between raffle run
     * 2 the raffle is in the OPEN state
     * 3 the contract has eth (aka players)
     * 4. (implicit) the subscription is funded with LINK
     */
    // if a function of ours requires an input parameter and for the chainlink nodes to recognise the function we need an input parameter but we're not going to use it, can just comment it out
    function checkUpkeep(
        bytes memory /**checkData */
    )
        public
        view
        returns (
            // if the variables are nameed like below, it automatically returns them without the need to use Return
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0"); //0x0 is how we can say its a blank bytes object
    }

    // 1. get a radom number from chainlink
    // 2. be automatically called when we have enough players
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // check to see if enough time has passed
        // if ((block.timestamp - s_lastTimeStamp) < i_interval) {
        //     revert();
        // }
        s_raffleState = RaffleState.CALCULATING;
        // this will make a request to the chainlink node to give us a random number.
        // its going to generate the random number and its going to call a contract on chain called the vrf coordinator where only the chainlink node can respond to that
        // that contract is going to call FulFilRandomWords which we are going to define by overriding it. basically saying now that we have the random number, what do we do?
        i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, // number of block confirmations in order for random number to be considered good
            i_callbackGasLimit, // max amount of gas to be used in the callback
            NUM_WORDS
        );
    }

    // rawFulfillRandomWords is the function that is called by the VRFCoordinator
    // when the chainlink node gets a random number, it calls the vrf coordinator.
    // The vrf coordinator will then call the vrfConsumberBaseV2 which is a part of our raffle contract as it needs to be overridden as is virtual
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory _randomWords
    ) internal override {
        // Checks
        // Effects (Our own contract)
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        // Interactions (Other contracts)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
