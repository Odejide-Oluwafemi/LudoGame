// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { Test, console2 } from "forge-std/Test.sol";
import { LudoGame } from "src/LudoGame.sol";

contract LudoGameTest  is Test {
  // Errors
  error LudoGame__AlreadyRegistered();
  error LudoGame__NotEnoughEntryFee();
  error LudoGame__GameAlreadyFull();
  error LudoGame__GameIsNotAcceptingEntries();

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
        uint32 startPos;
    }

  LudoGame game;

  uint constant PLAYERS_STARTING_AMOUNT = 10 ether;
  uint entryFee;

  address[4] players;

  function setUp() public {
    game = new LudoGame();
    entryFee = game.ENTRY_FEE();

    for (uint8 i; i < game.MAX_PLAYERS(); i++) {
      players[i] = makeAddr(string(abi.encodePacked(uint160(i * block.timestamp))));
      vm.deal(players[i], PLAYERS_STARTING_AMOUNT);
    }
  }

  modifier startGame() {
    address player1 = players[0];
    address player2 = players[1];
    address player3 = players[2];
    address player4 = players[3];

    vm.prank(player1);
    game.joinGame{value: entryFee}();

    vm.prank(player2);
    game.joinGame{value: entryFee}();

    vm.prank(player3);
    game.joinGame{value: entryFee}();

    vm.prank(player4);
    game.joinGame{value: entryFee}();

    _;
  }

  function test__UsersCanJoinGameButNotMoreThanOnceAndWithTheRequiredEntryFee() public {
    address player1 = players[0];

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

    assert(game.getNumberOfPlayersInGame() == game.MAX_PLAYERS());
    assertTrue(game.isGameStarted());

    // Cannot Join when Game is Full
    address dummy = makeAddr("Dummy Account");

    vm.deal(dummy, entryFee);
    vm.prank(dummy);

    vm.expectRevert(LudoGame__GameIsNotAcceptingEntries.selector);
    game.joinGame{value: entryFee}();
  }

  function test__ModifierWorks() public startGame {
    assertTrue(game.isGameStarted());
    assert(game.getPlayerInfo(players[0]).startPos == 0);
  }

  function test__ItShouldBeFirstPlayersTurnUponGameStart() public startGame {
    assertEq(game.getPlayerInTurn(), players[0]);
    assertEq(game.getGameTurns(), 0);

    // MAX_BOARD_LENGTH = (6 x (MAX_PLAYERS * 2)) + MAX_PLAYERS
    // MAX_BOARD_LENGTH = (6 x (4 x 2)) + 4 == 52

    // Therefore, startPos = uint32((MAX_BOARD_LENGTH / MAX_PLAYERS) * playersInGame.length);

    // players[0].startPos should be equal to (52 / 4) * 0 = 0
    // players[1].startPos should be equal to (52 / 4) * 1 = 13
    // players[2].startPos should be equal to (52 / 4) * 2 = 26
    // players[3].startPos should be equal to (52 / 4) * 3 = 39

    assertEq(game.getPlayerInfo(players[0]).startPos, 0);
    assertEq(game.getPlayerInfo(players[1]).startPos, 13);
    assertEq(game.getPlayerInfo(players[2]).startPos, 26);
    assertEq(game.getPlayerInfo(players[3]).startPos, 39);
  }

  function test__FirstPlayerPlaysAndEnsuresGameStateCorrectness() public startGame {
    address player = players[0];

    uint initialPosition = game.getTokenPosition(game.getPlayerInfo(player).tokenInPlay);
    assertEq(initialPosition, 0);

    vm.prank(player);

    uint8 roll = game.play();
    
    uint tokenPosition = game.getTokenPosition(game.getPlayerInfo(player).tokenInPlay);

    if (roll == 6) {
      assertEq(tokenPosition, 6);
    }
    else {
      // Can't move if starting roll is not a 6
      assertEq(game.getPlayerInfo(player).tokenInPlay.ownedBy, address(0));
      assertEq(tokenPosition, 0);
      assertEq(game.getPlayerInTurn(), players[1]);
    }
  }

  function test__Player1AndPlayer2Turns() public startGame {
    // Player 1 PLays
    address player1 = players[0];

    uint player1StartPos = game.getTokenPosition(game.getPlayerInfo(player1).tokenInPlay);
    assertEq(player1StartPos, 0);

    vm.prank(player1);

    uint8 roll1 = game.play();
    
    uint token1Position = game.getTokenPosition(game.getPlayerInfo(player1).tokenInPlay);

    if (roll1 == 6) {
      assertEq(token1Position, 6);
    }
    else {
      // Can't move if starting roll is not a 6
      assertEq(game.getPlayerInfo(player1).tokenInPlay.ownedBy, address(0));
      assertEq(token1Position, 0);
      assertEq(game.getPlayerInTurn(), players[1]);
    }

    // Assert that players cannot play if it' snot their turn yet

    // Player 2 Plays
    address player2 = players[1];

    uint initialPosition = game.getTokenPosition(game.getPlayerInfo(player2).tokenInPlay);
    assertEq(initialPosition, 0);

    vm.prank(player2);

    uint8 roll2 = game.play();
    
    uint token2Position = game.getTokenPosition(game.getPlayerInfo(player2).tokenInPlay);

    if (roll2 == 6) {
      uint startPos = (game.MAX_BOARD_LENGTH() / game.MAX_PLAYERS()) * 1;
      assertEq(token2Position, startPos + roll2);
    }
    else {
      // Can't deploy a token if starting roll is not a 6
      assertEq(game.getPlayerInfo(player2).tokenInPlay.ownedBy, address(0));
      assertEq(token2Position, 0);
      assertEq(game.getPlayerInTurn(), players[2]);
    }
  }
}