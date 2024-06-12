// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDeltaLibrary, BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";

import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {IncentiveHook} from "./IncentiveHook.sol";

import "forge-std/console.sol";

contract LPCompetition is ERC721Enumerable {

    using PoolIdLibrary for PoolKey;

    struct Competition {
        PoolId poolId;
        PoolKey poolKey;
        address prizeToken;
        uint256[] prizeAmounts;
        uint256 totalPrizes;
        uint256 startTime;
        uint256 registrationWindow;
        bool rewardsDeposited;
    }

    struct LPInfo {
        address lpAddress;
        uint256 startFees;
        uint256 endFees;
        bool registered;
        bool ended;
        bool claimed;
        uint256 rank;
    }

    mapping(uint256 => Competition) public competitions;
    mapping(uint256 => LPInfo[]) public competitionLPs;
    mapping(uint256 => mapping(address => LPInfo)) public lpDetails;
    uint256 public currentCompetitionId;
    uint256 public nextCompetitionId;
    uint256 public constant WEEK_DURATION = 7 * 24 * 60 * 60;
    uint256 public constant REGISTRATION_DURATION = 24 * 60 * 60;
    
    event CompetitionCreated(uint256 competitionId, uint256 startTime, PoolId poolId);
    event RewardsDeposited(uint256 competitionId, uint256 totalPrizes);
    event LPRegistered(uint256 competitionId, address lp);
    event LPParticipationEnded(uint256 competitionId, address lp, uint256 feesEarned);
    event RewardsClaimed(uint256 competitionId, address lp, uint256 amount, uint256 rank);

    IncentiveHook public incentiveHook;
    PoolModifyLiquidityTest public modifyLiquidityRouter;

    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;

    constructor(address _incentiveHook, address _modifyLiquidityRouter) ERC721("LPCompetitionBadge", "LPCB") {
        incentiveHook = IncentiveHook(_incentiveHook);
        modifyLiquidityRouter = PoolModifyLiquidityTest(_modifyLiquidityRouter);

        currentCompetitionId = 0;
        // nextCompetitionId = 1;
    }

    function createCompetition(PoolKey memory poolKey, address prizeToken, uint256[] memory prizeAmounts) external returns (uint256 competitionId) {
        require(prizeAmounts.length > 0, "Invalid reward amounts");
        require(currentCompetitionId == 0 || competitions[currentCompetitionId].startTime == 0, "Competition already in progress");
        
        PoolId poolId = poolKey.toId();

        currentCompetitionId += 1;

        uint256 totalPrizes = 0;
        for (uint256 i = 0; i < prizeAmounts.length; i++) {
            totalPrizes = totalPrizes + prizeAmounts[i];
        }

        uint256 startTime = block.timestamp + REGISTRATION_DURATION;
        competitions[currentCompetitionId] = Competition({
            poolId: poolId,
            poolKey: poolKey,
            prizeToken: prizeToken,
            prizeAmounts: prizeAmounts,
            totalPrizes: totalPrizes,
            startTime: startTime,
            registrationWindow: startTime - REGISTRATION_DURATION,
            rewardsDeposited: false
        });

        emit CompetitionCreated(currentCompetitionId, startTime, poolId);
        competitionId = currentCompetitionId;
    }

    function depositRewards(uint256 competitionId) external {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp < comp.startTime, "Competition already started");
        require(!comp.rewardsDeposited, "Rewards already deposited");

        IERC20 prizeToken = IERC20(comp.prizeToken);
        console.log("IN CONTRACT LPCompetition prizeToken address: %s", address(prizeToken));
        console.log("IN CONTRACT LPCompetition depozitRewards comp.totalPrizes", comp.totalPrizes);
        prizeToken.transferFrom(msg.sender, address(this), comp.totalPrizes);
        console.log("IN CONTRACT LPCompetition depozitRewards balance: %s", prizeToken.balanceOf(address(this)));

        comp.rewardsDeposited = true;

        emit RewardsDeposited(competitionId, comp.totalPrizes);
    }

    function registerForCompetition(address competitor, uint256 competitionId, IPoolManager.ModifyLiquidityParams memory params) external {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp < comp.startTime, "Registration closed");
        require(!lpDetails[competitionId][competitor].registered, "Already registered");

        // Call the poke function on the hook contract to get start fees
        PoolKey memory key = comp.poolKey;
        BalanceDelta feesAccrued = modifyLiquidityRouter.modifyLiquidity(key, params, ZERO_BYTES, false, false);


        // TODO for now only amount0 is used, need to update to use both amount0 and amount1
        uint256 startFees = uint256(int256(BalanceDeltaLibrary.amount0(feesAccrued)));

        lpDetails[competitionId][competitor] = LPInfo({
            lpAddress: competitor,
            startFees: startFees,
            endFees: 0,
            registered: true,
            ended: false,
            claimed: false,
            rank: 0
        });

        competitionLPs[competitionId].push(lpDetails[competitionId][competitor]);

        emit LPRegistered(competitionId, competitor);
    }

    function endParticipation(address competitor, uint256 competitionId) external {
        LPInfo storage lp = lpDetails[competitionId][competitor];
        require(lp.registered, "Not registered");
        require(!lp.ended, "Already ended participation");
        require(block.timestamp < competitions[competitionId].startTime + WEEK_DURATION, "Participation window closed");

        // Call the poke function on the hook contract to get end fees (pseudo-code)
        // PoolKey memory key;
        // PositionParams memory params;
        // uint256 endFees = hookContract.poke(key, params);

        uint256 endFees = 0; // Replace with actual poke function call

        lp.endFees = endFees;
        lp.ended = true;

        emit LPParticipationEnded(competitionId, competitor, lp.endFees - lp.startFees);
    }

    function calculateRankings(uint256 competitionId) external {
        Competition storage comp = competitions[competitionId];
        console.log("Block timestamp: %s", block.timestamp);
        console.log("Block number: %s", block.number);
        console.log("Competition start time: %s", comp.startTime);
        console.log("Competition end time: %s", comp.startTime + WEEK_DURATION);
        require(block.timestamp >= comp.startTime + WEEK_DURATION, "Competition not ended");

        LPInfo[] storage lps = competitionLPs[competitionId];

        // Sort LPs by fees earned in descending order
        for (uint256 i = 0; i < lps.length; i++) {
            for (uint256 j = i + 1; j < lps.length; j++) {
                if (lps[j].endFees - lps[j].startFees > lps[i].endFees - lps[i].startFees) {
                    LPInfo memory temp = lps[i];
                    lps[i] = lps[j];
                    lps[j] = temp;
                }
            }
        }

        // Assign ranks
        for (uint256 i = 0; i < lps.length && i < comp.prizeAmounts.length; i++) {
            lps[i].rank = i + 1;
            lpDetails[competitionId][lps[i].lpAddress].rank = lps[i].rank;

            // Mint SBT as a badge
            mintSoulboundToken(lps[i].lpAddress, competitionId);

            // // Distribute rewards
            // IERC20 prizeToken = IERC20(comp.prizeToken);
            // prizeToken.transfer(lps[i].lpAddress, comp.prizeAmounts[i]);

            emit RewardsClaimed(competitionId, lps[i].lpAddress, comp.prizeAmounts[i], lps[i].rank);
        }
    }

    function mintSoulboundToken(address participant, uint256 competitionId) public {
        // Mint SBT as a badge with rank field set to whatever rank the participant achieved
        uint256 rank = lpDetails[competitionId][participant].rank;
        console.log("Minting SBT for participant %s with rank %s", participant, rank);
        
        //_mint(participant, competitionId, rank);
    }

    function claimPrize(address participant, uint256 competitionId) external returns (uint256 prizeAmount) {
        LPInfo storage lp = lpDetails[competitionId][participant];
        require(lp.ended, "Participation not ended");
        require(!lp.claimed, "Prizes already claimed");

        Competition storage comp = competitions[competitionId];
            if (lp.rank > 0 && lp.rank <= comp.prizeAmounts.length) {

            // Mark as claimed
            lp.claimed = true;

            // Transfer the reward
            IERC20 prizeToken = IERC20(comp.prizeToken);
            console.log("IN CONTRACT LPCompetition claimPrize prizeToken address: %s", address(prizeToken));
            uint256 balance = prizeToken.balanceOf(address(this));
            console.log("IN CONTRACT LPCompetition claimPrize Balance of prize token: %s", balance);
            prizeToken.transfer(participant, comp.prizeAmounts[lp.rank - 1]);

            prizeAmount = comp.prizeAmounts[lp.rank - 1];

            emit RewardsClaimed(competitionId, participant, comp.prizeAmounts[lp.rank - 1], lp.rank);
        } else {
            prizeAmount = 0;
        }
    }

    function getLPInfo(uint256 competitionId, address participant) external view returns (LPInfo memory) {
        return lpDetails[competitionId][participant];
    }

    function claimExtraFees(address participant, uint256 competitionId) external returns (uint256 retainedFees) {
        LPInfo storage lp = lpDetails[competitionId][participant];
        require(lp.ended, "Participation not ended");
        require(lp.claimed, "Prizes not claimed");

        // Transfer the retained fees
        // IERC20 prizeToken = IERC20(comp.prizeToken);
        // prizeToken.transfer(participant, lp.endFees - lp.startFees);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
