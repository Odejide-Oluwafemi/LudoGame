// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {HelperFunctions} from "src/HelperFunctions.sol";

contract LudoGame {
    // Errors
    error LudoGame__AlreadyRegistered();
    error LudoGame__NotEnoughEntryFee();
    error LudoGame__RefundFailed();
    error LudoGame__GameAlreadyFull();
    error LudoGame__PlayingOutOfTurn();
    error LudoGame__YouHaveNoMoreTokenLeft();
    error LudoGame__SendWinnerRewardFailed();
    error LudoGame__GameIsNotAcceptingEntries();

    // Events
    event PlayerJoined(address indexed player);
    event GameStarted(address[] players, uint256 timestamp);
    event TurnPassed(uint256 indexed gameTurns, address formerPlayer, address playerInTurn);
    event PlayerEliminated(address indexed player);
    event GameOver(address indexed winner);

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

    uint256 public constant ENTRY_FEE = 1 ether;
    uint256 public constant MAX_BOARD_LENGTH = (6 * (MAX_PLAYERS * 2)) + MAX_PLAYERS;
    uint8 public constant MAX_PLAYERS = 4;
    uint8 public constant STARTING_TOKEN_COUNT = 4;

    bool private gameStarted = false;
    address private playerInTurn;
    uint8 private gameTurns;

    address[MAX_PLAYERS] private players;
    address[] private playersInGame;
    mapping(address player => Player info) private playerInfo;
    mapping(uint256 space => Token token) private tokenOnSpace;

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
        if (gameStarted) revert LudoGame__GameIsNotAcceptingEntries();
        if (players[players.length - 1] != address(0)) revert LudoGame__GameAlreadyFull();

        Player storage player = playerInfo[msg.sender];

        if (player.addr != address(0)) revert LudoGame__AlreadyRegistered();
        if (msg.value < ENTRY_FEE) revert LudoGame__NotEnoughEntryFee();

        player.addr = msg.sender;
        player.tokenLeft = STARTING_TOKEN_COUNT;
        playerInfo[msg.sender] = player;

        players[playersInGame.length] = msg.sender;
        playersInGame.push(msg.sender);

        // Handle Refund of excess entry fee
        if (msg.value > ENTRY_FEE) {
            uint256 refund = msg.value - ENTRY_FEE;

            (bool success,) = msg.sender.call{value: refund}("");

            if (!success) revert LudoGame__RefundFailed();
        }

        emit PlayerJoined(msg.sender);

        if (playersInGame.length == MAX_PLAYERS) initializeGame();
    }

    function initializeGame() private {
        playerInTurn = getPlayerInTurn();
        gameStarted = true;

        emit GameStarted(playersInGame, block.timestamp);
    }

    function passTurn() internal {
        address formerPlayer = getPlayerInTurn();

        gameTurns = gameTurns + 1;
        playerInTurn = getPlayerInTurn();

        emit TurnPassed(gameTurns, formerPlayer, playerInTurn);
    }

    function play() external onlyPlayerInTurn {
        Player storage player = playerInfo[msg.sender];
        uint8 roll = HelperFunctions.rollDie(abi.encode(player.addr, block.timestamp, player.tokenInPlay));

        // Handle Rolling Doubles for extra turn
        if (roll == 6) {
            _play(player, roll, 1);
        } else {
          // If Player Has no Token in play...
            if (player.tokenInPlay.ownedBy == address(0)) {
              // But has tokensLeft...
                if (player.tokenLeft > 0) {
                  // And played a 6...
                    if (roll == 6) bringOutToken(player);
                    // Then bringOutToken, else passTurn
                    else passTurn();
                } else {
                  // If Player Has no Token in play, and no tokenLeft, elimatePlayer (if not elimated before for whatever buggish reason)
                    eliminatePlayer(player.addr);
                    passTurn();
                }
            }

            // But if player has token in Play already
            move(player, roll);
        }
    }

    function _play(Player storage player, uint8 roll, uint count) private {
      if (count == 3) {
        passTurn();
      }
      else {
        count = count + 1;
        
        move(player, roll);
      }

        // Handle Rolling Doubles for extra turn
        if (roll == 6) {
            _play(player, roll, count);
        }
    }

    function eliminatePlayer(address player) private {
        for (uint8 i; i < playersInGame.length; i++) {
            if (playersInGame[i] == player) {
                playersInGame[i] = playersInGame[playersInGame.length - 1];
                playersInGame.pop();
            }
        }

        emit PlayerEliminated(player);
    }

    function capture(Token storage tokenCapturing) private {
      // Capture Logic
            Player storage capturedPlayer = playerInfo[tokenCapturing.ownedBy];
            uint32 contendingSpace = tokenCapturing.position;

            capturedPlayer.tokenLeft = capturedPlayer.tokenLeft - 1;

            capturedPlayer.tokenInPlay = Token({id: bytes32(0), ownedBy: address(0), position: 0});

            // Player Eliminated
            if (capturedPlayer.tokenLeft == 0) {
                eliminatePlayer(capturedPlayer.addr);
            }

            // If there remains only 1 player, GameOver, and send reward
            if (playersInGame.length == 1) {
                (bool success,) = playersInGame[0].call{value: address(this).balance}("");
                gameStarted = false;

                if (!success) revert LudoGame__SendWinnerRewardFailed();

                emit GameOver(playersInGame[0]);
            }

            tokenOnSpace[contendingSpace] = tokenCapturing;
    }

    function move(Player storage player, uint8 roll) private {
        uint32 spaceToLand = uint32((player.tokenInPlay.position + roll) % MAX_BOARD_LENGTH);

        // Capture if any token is on the spaceToLand
        if (tokenOnSpace[spaceToLand].ownedBy != address(0)) capture(player.tokenInPlay);
        
        tokenOnSpace[spaceToLand] = player.tokenInPlay;
        player.tokenInPlay.position = player.tokenInPlay.position + roll;

        passTurn();
    }

    // Getter Functions
    function getPlayerInfo(address player) external view returns (Player memory) {
        return playerInfo[player];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getNumberOfPlayersInGame() external view returns (uint8) {
        return uint8(playersInGame.length);
    }

    function isGameStarted() external view returns (bool) {
        return gameStarted;
    }

    function getPlayerBoardPosition(address player) external view returns (uint32) {
        return playerInfo[player].tokenInPlay.position;
    }

    function getTokenOnSpace(uint32 space) external view returns (Token memory) {
        return tokenOnSpace[space];
    }

    function getPlayerInTurn() internal view returns (address) {
        return (playersInGame[gameTurns % MAX_PLAYERS]);
    }
}
