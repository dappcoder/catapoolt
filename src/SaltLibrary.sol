// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library SaltLibrary {
    struct Salt {
        address addr;
        uint16 index;
    }

    function toSalt(address addr, uint16 index) internal pure returns (bytes32) {
        require(index < 2**12, "Index must be a uint12 value");
        return bytes32((uint256(uint160(addr)) << 96) | index);
    }

    function fromSalt(bytes32 salt) internal pure returns (address, uint16) {
        address addr = address(uint160(uint256(salt) >> 96));
        uint16 index = uint16(uint256(salt) & 0xFFF); // 0xFFF is the mask for the last 12 bits
        return (addr, index);
    }

    function encode(Salt memory s) internal pure returns (bytes32) {
        return toSalt(s.addr, s.index);
    }

    function decode(bytes32 salt) internal pure returns (Salt memory) {
        (address addr, uint16 index) = fromSalt(salt);
        return Salt(addr, index);
    }
}
