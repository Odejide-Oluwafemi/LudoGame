// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { HelperFunctions } from "src/HelperFunctions.sol";

contract LudoGame {
  // Errors
  error LudoGame__AlreadyRegistered();
  error LudoGame__NotEnoughEntryFee();
  error LudoGame__RefundFailed();
  error LudoGame__GameAlreadyFull();
  error LudoGame__PlayingOutOfTurn();
  error LudoGame__YouHaveNoMoreTokenLeft();

  // Events
  event PlayerJoined(address indexed player);

  struct Token {
    bytes32 id;
    address ownedBy;
    uint32 position;
  }

  struct Player {
    address addr;
    uint8 tokenLeft;
    Token tokenInPlay;
  }


  uint public constant ENTRY_FEE = 1 ether;
  uint public constant MAX_BOARD_LENGTH = (6 * (MAX_PLAYERS * 2)) + MAX_PLAYERS;
  uint8 public constant MAX_PLAYERS = 4;
  uint8 public constant STARTING_TOKEN_COUNT = 4;

  uint8 private playersCount;
  bool private gameStarted = false;
  address private playerInTurn;
  uint8 private gameTurns;

  address[MAX_PLAYERS] private players;
  mapping (address player => Player info) private playerInfo;
  mapping (uint space => Token token) private tokenOnSpace;
  
  // Modifiers
  modifier onlyPlayerInTurn() {
    if (msg.sender != playerInTurn) revert LudoGame__PlayingOutOfTurn();

    _;
  }

  function bringOutToken(Player storage player) internal {
    if (player.tokenLeft == 0) revert LudoGame__YouHaveNoMoreTokenLeft();

    player.tokenInPlay = Token({
      id: HelperFunctions.computeTokenId(abi.encodePacked(player.addr, player.tokenLeft, block.timestamp)),
      ownedBy: player.addr,
      position: 0
    });

    passTurn();
  }

  function joinGame() external payable {
    if (playersCount == MAX_PLAYERS) revert LudoGame__GameAlreadyFull();

    Player storage player = playerInfo[msg.sender];

    if (player.addr != address(0)) revert LudoGame__AlreadyRegistered();
    if (msg.value < ENTRY_FEE) revert LudoGame__NotEnoughEntryFee();

    player.addr = msg.sender;
    players[playersCount] = msg.sender;
    playersCount = playersCount + 1;

    // Handle Refund of excess entry fee
    if (msg.value > ENTRY_FEE) {
      uint refund = msg.value - ENTRY_FEE;

      (bool success, ) = msg.sender.call{value: refund}("");

      if (!success) revert LudoGame__RefundFailed();
    }

    if (playersCount == MAX_PLAYERS) initializeGame();

    emit PlayerJoined(msg.sender);
  }

  function initializeGame() private {
    playerInTurn = getPlayerInTurn();
    gameStarted = true;
  }

  function passTurn() internal {
    gameTurns = gameTurns + 1;
    playerInTurn = getPlayerInTurn();
  }

  function play() external onlyPlayerInTurn {
    Player storage player = playerInfo[msg.sender];
    uint8 roll = HelperFunctions.rollDie(abi.encode(player.addr, block.timestamp, player.tokenInPlay));

    if (player.tokenInPlay.ownedBy == address(0)) {
      if (player.tokenLeft > 0) {
        if (roll == 6) bringOutToken(player);
        else passTurn();
      }
      else revert LudoGame__YouHaveNoMoreTokenLeft();
    }

    uint32 spaceToLand = uint32((player.tokenInPlay.position + roll) % MAX_BOARD_LENGTH);

    moveAndCapture(player, spaceToLand);
  }

  function moveAndCapture(Player storage player, uint spaceToLand) private {
    Token storage tokenOccupyingSpace = tokenOnSpace[spaceToLand];

    // No Token on that space, procees as normal
    if (tokenOccupyingSpace.ownedBy == address(0)) tokenOnSpace[spaceToLand] = player.tokenInPlay;
    else {
      // Capture Logic
      Player storage capturedPlayer = playerInfo[tokenOccupyingSpace.ownedBy];
      
      capturedPlayer.tokenLeft = capturedPlayer.tokenLeft - 1;
      
      capturedPlayer.tokenInPlay = Token({
        id: bytes32(0),
        ownedBy: address(0),
        position: 0
      });

      tokenOnSpace[spaceToLand] = player.tokenInPlay;
    }

    passTurn();
  }

  // Getter Functions
  function getPlayerInfo(address player) external view returns (Player memory) {
    return playerInfo[player];
  }

  function getContractBalance() external view returns (uint) {
    return address(this).balance;
  }

  function getNumberOfPlayersJoined() external view returns (uint8) {
    return playersCount;
  }

  function isGameStarted() external view returns (bool) {
    return gameStarted;
  }

  function getPlayerBoardPosition(address player) external view returns(uint32) {
    return playerInfo[player].tokenInPlay.position;
  }

  function getTokenOnSpace(uint32 space) external view returns (Token memory) {
    return tokenOnSpace[space];
  }

  function getPlayerInTurn() internal view returns (address) {
    return (players[gameTurns % MAX_PLAYERS]);
  }
}