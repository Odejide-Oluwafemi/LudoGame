// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library HelperFunctions {
    function rollDie(bytes memory salt) external pure returns (uint8) {
        return (uint8(uint256(bytes32(abi.encodePacked(salt, bytes1(0xFF))))) % 6) + 1;
    }

    function computeTokenId(bytes memory salt) external pure returns (bytes32) {
        return bytes32(keccak256(salt));
    }
}
