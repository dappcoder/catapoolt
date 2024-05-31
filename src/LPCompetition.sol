// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract LPCompetition is ERC721Enumerable {

    struct Competition {
        uint256 rewardPoolId;
        address rewardToken;
        uint256[] rewardAmounts;
        uint256 totalRewards;
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
    
    event CompetitionCreated(uint256 competitionId, uint256 startTime, uint256 rewardPoolId);
    event RewardsDeposited(uint256 competitionId, uint256 totalRewards);
    event LPRegistered(uint256 competitionId, address lp);
    event LPParticipationEnded(uint256 competitionId, address lp, uint256 feesEarned);
    event RewardsClaimed(uint256 competitionId, address lp, uint256 amount, uint256 rank);

    constructor() ERC721("LPCompetitionBadge", "LPCB") {
        currentCompetitionId = 1;
        nextCompetitionId = 1;
    }

    function createCompetition(uint256 rewardPoolId, address rewardToken, uint256[] memory rewardAmounts) external {
        require(rewardAmounts.length > 0, "Invalid reward amounts");
        require(competitions[nextCompetitionId].startTime == 0, "Competition already exists");

        uint256 totalRewards = 0;
        for (uint256 i = 0; i < rewardAmounts.length; i++) {
            totalRewards = totalRewards + rewardAmounts[i];
        }

        uint256 startTime = block.timestamp + REGISTRATION_DURATION;
        competitions[nextCompetitionId] = Competition({
            rewardPoolId: rewardPoolId,
            rewardToken: rewardToken,
            rewardAmounts: rewardAmounts,
            totalRewards: totalRewards,
            startTime: startTime,
            registrationWindow: startTime - REGISTRATION_DURATION,
            rewardsDeposited: false
        });

        emit CompetitionCreated(nextCompetitionId, startTime, rewardPoolId);
        nextCompetitionId = nextCompetitionId + 1;
    }

    function depositRewards(uint256 competitionId) external {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp < comp.startTime, "Competition already started");
        require(!comp.rewardsDeposited, "Rewards already deposited");

        IERC20 rewardToken = IERC20(comp.rewardToken);
        rewardToken.transferFrom(msg.sender, address(this), comp.totalRewards);
        comp.rewardsDeposited = true;

        emit RewardsDeposited(competitionId, comp.totalRewards);
    }

    function registerForCompetition(uint256 competitionId) external {
        Competition storage comp = competitions[competitionId];
        require(block.timestamp >= comp.registrationWindow && block.timestamp < comp.startTime, "Registration closed");
        require(!lpDetails[competitionId][msg.sender].registered, "Already registered");

        // Call the poke function on the hook contract to get start fees (pseudo-code)
        // PoolKey memory key;
        // PositionParams memory params;
        // uint256 startFees = hookContract.poke(key, params);

        uint256 startFees = 0; // Replace with actual poke function call

        lpDetails[competitionId][msg.sender] = LPInfo({
            lpAddress: msg.sender,
            startFees: startFees,
            endFees: 0,
            registered: true,
            ended: false,
            claimed: false,
            rank: 0
        });

        competitionLPs[competitionId].push(lpDetails[competitionId][msg.sender]);

        emit LPRegistered(competitionId, msg.sender);
    }

    function endParticipation(uint256 competitionId) external {
        LPInfo storage lp = lpDetails[competitionId][msg.sender];
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

        emit LPParticipationEnded(competitionId, msg.sender, lp.endFees - lp.startFees);
    }

    function calculateRankings(uint256 competitionId) external {
        Competition storage comp = competitions[competitionId];
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

        // Assign ranks and distribute rewards
        for (uint256 i = 0; i < lps.length && i < comp.rewardAmounts.length; i++) {
            lps[i].rank = i + 1;
            lpDetails[competitionId][lps[i].lpAddress].rank = lps[i].rank;

            // Mint SBT as a badge
            _mint(lps[i].lpAddress, competitionId);

            // Distribute rewards
            IERC20 rewardToken = IERC20(comp.rewardToken);
            rewardToken.transfer(lps[i].lpAddress, comp.rewardAmounts[i]);

            emit RewardsClaimed(competitionId, lps[i].lpAddress, comp.rewardAmounts[i], lps[i].rank);
        }
    }

    function claimRewards(uint256 competitionId) external {
        LPInfo storage lp = lpDetails[competitionId][msg.sender];
        require(lp.ended, "Participation not ended");
        require(!lp.claimed, "Rewards already claimed");

        Competition storage comp = competitions[competitionId];
        require(lp.rank > 0 && lp.rank <= comp.rewardAmounts.length, "No rewards available");

        // Mark as claimed
        lp.claimed = true;

        // Transfer the reward
        IERC20 rewardToken = IERC20(comp.rewardToken);
        rewardToken.transfer(msg.sender, comp.rewardAmounts[lp.rank - 1]);

        emit RewardsClaimed(competitionId, msg.sender, comp.rewardAmounts[lp.rank - 1], lp.rank);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
