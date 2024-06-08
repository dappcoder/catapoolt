// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "brevis-sdk/apps/framework/BrevisApp.sol";
import "brevis-sdk/interface/IBrevisProof.sol";

/// @title Leaderboard
/// This contract is used to: 
/// * store the leaderboard of the top N LPs of the previous week (through a Brevis handler function)
/// * mint soulbound tokens to top N(configurable) LPs (through the brevis handler function)
/// * soulbound token attributes are (name, symbol, week, rank, pool ID)
contract Leaderboard is BrevisApp, ERC721Enumerable, ERC721Burnable, Ownable {
    bytes32 public vkHash;
    uint256 public week;
    uint256 public topN;
    mapping(uint256 => LeaderboardEntry) public leaderboard;

    struct LeaderboardEntry {
        address lpAddress;
        uint256 rank;
        uint256 poolId;
    }

    constructor(
        IBrevisProof _brevisProof,
        uint256 _week,
        uint256 _topN
    ) BrevisApp(_brevisProof) ERC721("LeaderboardToken", "LBT") Ownable(msg.sender) {
        week = _week;
        topN = _topN;
    }

    function handleProofResult(
        bytes32 _requestId,
        bytes32 _vkHash,
        bytes calldata _appCircuitOutput
    ) public override {
        require(vkHash == _vkHash, "invalid vk");
        (address[] memory lpAddresses, uint256[] memory ranks, uint256[] memory poolIds) = decodeOutput(_appCircuitOutput);

        for (uint256 i = 0; i < topN; i++) {
            leaderboard[i] = LeaderboardEntry(lpAddresses[i], ranks[i], poolIds[i]);
            _mintSoulboundToken(lpAddresses[i], ranks[i], poolIds[i]);
        }
    }

    function decodeOutput(
        bytes calldata output
    ) internal pure returns (address[] memory, uint256[] memory, uint256[] memory) {
        uint256 numEntries = output.length / 96;
        address[] memory lpAddresses = new address[](numEntries);
        uint256[] memory ranks = new uint256[](numEntries);
        uint256[] memory poolIds = new uint256[](numEntries);

        for (uint256 i = 0; i < numEntries; i++) {
            lpAddresses[i] = address(bytes20(output[i * 96: i * 96 + 20]));
            ranks[i] = uint256(bytes32(output[i * 96 + 20: i * 96 + 52]));
            poolIds[i] = uint256(bytes32(output[i * 96 + 52: i * 96 + 84]));
        }

        return (lpAddresses, ranks, poolIds);
    }

    function setVkHash(bytes32 _vkHash) external onlyOwner {
        vkHash = _vkHash;
    }

    function _mintSoulboundToken(
        address lpAddress,
        uint256 rank,
        uint256 poolId
    ) internal {
        uint256 tokenId = totalSupply() + 1;
        _safeMint(lpAddress, tokenId);

        emit MintSoulboundToken(lpAddress, tokenId, week, rank, poolId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        require(from == address(0), "Soulbound tokens are non-transferable");
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    event MintSoulboundToken(
        address indexed lpAddress,
        uint256 indexed tokenId,
        uint256 week,
        uint256 rank,
        uint256 poolId
    );

    
}
