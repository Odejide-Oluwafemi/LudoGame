// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract LudoGame {
  // Errors
  error LudoGame__AlreadyRegistered();
  error LudoGame__NotEnoughEntryFee();
  error LudoGame__RefundFailed();
  error LudoGame__GameAlreadyFull();

  // Events
  event PlayerJoined(address indexed player);

  struct Player {
    address addr;
    uint position;
  }

  uint public constant ENTRY_FEE = 1 ether;
  uint8 public constant MAX_PLAYERS = 4;
  uint8 private playersCount;
  bool private gameStarted = false;
  
  mapping(address => Player info) private playerInfo;

  function joinGame() external payable {
    if (playersCount == MAX_PLAYERS) revert LudoGame__GameAlreadyFull();

    Player storage player = playerInfo[msg.sender];

    if (player.addr != address(0)) revert LudoGame__AlreadyRegistered();
    if (msg.value < ENTRY_FEE) revert LudoGame__NotEnoughEntryFee();

    player.addr = msg.sender;
    playersCount = playersCount + 1;

    // Handle Refund of excess entry fee
    if (msg.value > ENTRY_FEE) {
      uint refund = msg.value - ENTRY_FEE;

      (bool success, ) = msg.sender.call{value: refund}("");

      if (!success) revert LudoGame__RefundFailed();
    }

    if (playersCount == MAX_PLAYERS) gameStarted = true;

    emit PlayerJoined(msg.sender);
  }

  function getPlayerInfo(address playerAddress) external view returns (Player memory) {
    return playerInfo[playerAddress];
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

  function getPlayerBoardPosition() external view
}