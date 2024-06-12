// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/SaltLibrary.sol"; // Adjust the path to your SaltLibrary

contract SaltLibraryTest is Test {
    using SaltLibrary for SaltLibrary.Salt;

    function test_salt_ToSalt() public {
        address addr = 0x1234567890123456789012345678901234567890;
        uint16 index = 1234; // Example uint12 value
        bytes32 salt = SaltLibrary.toSalt(addr, index);
        (address extractedAddr, uint16 extractedIndex) = SaltLibrary.fromSalt(salt);
        assertEq(addr, extractedAddr, "Addresses should match");
        assertEq(index, extractedIndex, "Indices should match");
    }

    function test_salt_FromSalt() public {
        bytes32 salt = SaltLibrary.toSalt(0x1234567890123456789012345678901234567890, 1234);
        (address addr, uint16 index) = SaltLibrary.fromSalt(salt);
        assertEq(addr, 0x1234567890123456789012345678901234567890, "Address should be extracted correctly");
        assertEq(index, 1234, "Index should be extracted correctly");
    }

    function test_salt_EncodeDecode() public {
        SaltLibrary.Salt memory saltStruct = SaltLibrary.Salt({
            addr: 0x1234567890123456789012345678901234567890,
            index: 1234
        });

        bytes32 salt = SaltLibrary.encode(saltStruct);
        SaltLibrary.Salt memory decodedStruct = SaltLibrary.decode(salt);

        assertEq(saltStruct.addr, decodedStruct.addr, "Addresses should match");
        assertEq(saltStruct.index, decodedStruct.index, "Indices should match");
    }
}
