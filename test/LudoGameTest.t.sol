// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test, console2 } from "forge-std/Test.sol";
import { LudoGame } from "src/LudoGame.sol";

contract LudoGameTest  is Test {
  // Errors
  error LudoGame__AlreadyRegistered();
  error LudoGame__NotEnoughEntryFee();
  error LudoGame__GameAlreadyFull();

  // Events
  event PlayerJoined(address indexed player);

  LudoGame game;

  uint constant PLAYERS_STARTING_AMOUNT = 10 ether;
  address[4] players;

  function setUp() public {
    game = new LudoGame();

    for (uint8 i; i < game.MAX_PLAYERS(); i++) {
      players[i] = makeAddr(string(abi.encodePacked(uint160(i * block.timestamp))));
      vm.deal(players[i], PLAYERS_STARTING_AMOUNT);
    }
  }

  function test__UsersCanJoinGameButNotMoreThanOnceAndWithTheRequiredEntryFee() public {
    address player1 = players[0];
    uint entryFee = game.ENTRY_FEE();

    vm.startPrank(player1);

    // Test Revert With Insufficient Entry Fee
    vm.expectRevert(LudoGame__NotEnoughEntryFee.selector);
    game.joinGame{value: entryFee - 1}();

    // Successfully Registers and Emit; gets refunded of any extra ETH sent for registration
    vm.expectEmit();
    emit PlayerJoined(player1);
    game.joinGame{value: 2 * entryFee}();

    assert(game.getPlayerInfo(player1).addr == player1);
    assert(game.getContractBalance() == entryFee);

    // Test Duplicate Registration
    vm.expectRevert(LudoGame__AlreadyRegistered.selector);
    game.joinGame{value: entryFee}();

    vm.stopPrank();

    // Test only Max Players can register
    address player2 = players[1];
    address player3 = players[2];
    address player4 = players[3];

    vm.prank(player2);
    game.joinGame{value: entryFee}();

    vm.prank(player3);
    game.joinGame{value: entryFee}();

    vm.prank(player4);
    game.joinGame{value: entryFee}();

    assert(game.getNumberOfPlayersJoined() == game.MAX_PLAYERS());
    assertTrue(game.isGameStarted());

    // Cannot Join when Game is Full
    address dummy = makeAddr("Dummy Account");

    vm.deal(dummy, entryFee);
    vm.prank(dummy);

    vm.expectRevert(LudoGame__GameAlreadyFull.selector);
    game.joinGame{value: entryFee}();
  }
}