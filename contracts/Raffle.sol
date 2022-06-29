//Raffle
//Enter lottery, pay amount, pick a random winner, winner to be selected every X time -> completely automated
//Chainlink oracle -> randomness, automated execution

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__notEnoughEthEntered();
error Raffle__transferFailed();
error Raffle__notOpened();
error Raffle__upkeepNotNeeded(uint256 currBalance, uint256 noPlayers, uint256 RaffleState);

/**
@title A sample Raffle contract
@author Adam Kattan
@notice this contract is for creating and untamperable decentralized smart contract
@dev This implements Chainlink VRF v.2 and Chainlink Keepers
 */

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */
    //Enums stejne jak v cecku, vycet prvku
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable iEntranceFee;
    address payable[] private sPlayers;
    VRFCoordinatorV2Interface private immutable iVrfCoordinator;
    bytes32 private immutable iGasLane;
    uint64 private immutable iSubscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable iCallbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    /* Lottery variables */
    address private sRecentWinner;
    RaffleState private sRaffleState;
    uint256 private sLastTimestamp;
    uint256 private immutable iInterval;

    /* Events */

    event EnterRaffle(address indexed player);
    event RequestedRaffleWinner(uint256 indexedRequestId);
    event WinnerPicked(address indexedWinner);

    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        iEntranceFee = entranceFee;
        iVrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        iGasLane = gasLane;
        iSubscriptionId = subscriptionId;
        iCallbackGasLimit = callbackGasLimit;
        sRaffleState = RaffleState.OPEN;
        sLastTimestamp = block.timestamp;
        iInterval = interval;
    }

    /* Functions */

    function enterRaffle() public payable {
        if (msg.value < iEntranceFee) {
            revert Raffle__notEnoughEthEntered();
        }

        if (sRaffleState != RaffleState.OPEN) {
            revert Raffle__notOpened();
        }
        sPlayers.push(payable(msg.sender));
        //Emit an event when we update a dynamic array or mapping
        emit EnterRaffle(msg.sender);
    }

    /**
     * @dev This is the function that the chainlink keeper nodes call
     * They look for the upkeep needed to return true
     */

    function checkUpkeep(
        bytes memory /*checkData*/
    )
        public
        override
        returns (
            bool upkeedNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = RaffleState.OPEN == sRaffleState;
        bool timePassed = ((block.timestamp - sLastTimestamp) > iInterval);
        bool hasPlayers = (sPlayers.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeedNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        return (upkeedNeeded, "0x0");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        //Request random number than do smthing
        (bool upkeedNeeded, ) = checkUpkeep("");
        if (!upkeedNeeded) {
            revert Raffle__upkeepNotNeeded(
                address(this).balance,
                sPlayers.length,
                uint256(sRaffleState)
            );
        }
        sRaffleState = RaffleState.CALCULATING;
        uint256 requestId = iVrfCoordinator.requestRandomWords(
            iGasLane,
            iSubscriptionId,
            REQUEST_CONFIRMATIONS,
            iCallbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /*requestId*/
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];

        sRecentWinner = recentWinner;
        sRaffleState = RaffleState.OPEN;

        sPlayers = new address payable[](0); //reseting sPlayers to a new address array
        sLastTimestamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__transferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /* View / Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return iEntranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return sPlayers[index];
    }

    function getRecentWinner() public view returns (address) {
        return sRecentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return sRaffleState;
    }

    function getNumWords() public pure returns (uint256) {
        //MIsto view je zde pure protoze vracime konstantu ktera neni ulozena ve storage
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return sPlayers.length;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return sLastTimestamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return iInterval;
    }
}
