// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IncentiveHook} from "./IncentiveHook.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "brevis-sdk/apps/framework/BrevisApp.sol";
import "brevis-sdk/interface/IBrevisProof.sol";

contract OGMultiplier is BrevisApp, Ownable {

    event OfferingCreated(address indexed currency, uint256 amount, PoolId indexed poolId, uint256 multiplier);
    event OfferingToppedUp(address indexed currency, uint256 amount, PoolId indexed poolId);
    event RewardsWithdrawn(address lp, PoolId poolId, uint256 rewardAmount);

    struct Offering {
        address currency;
        uint256 amount;
        PoolId poolId;
        uint256 multiplier;
    }

    modifier onlySponsor(PoolId poolId) {
        // TODO verify whatever is needed to check if the caller is the sponsor of the pool
        _;
    }

    IncentiveHook public incentiveHook;

    bytes32 public vkHash;

    mapping(address => Offering[]) internal offerings;
    mapping(address => uint256) internal offeringLengths;
    mapping(address => mapping(PoolId => uint256)) internal ogMultipliers;
    mapping(address => mapping(PoolId => uint256)) internal rewardBalances;

    constructor(
        address _incentiveHook,
        IBrevisProof _brevisProof
    ) BrevisApp(_brevisProof) Ownable(msg.sender) {
        incentiveHook = IncentiveHook(_incentiveHook);
    }

    function handleProofResult(
        bytes32 _requestId,
        bytes32 _vkHash,
        bytes calldata _appCircuitOutput
    ) internal override {
        require(vkHash == _vkHash, "invalid vk");
        (address[] memory ogAddresses, address[] memory currencies, uint256[] memory amounts) = decodeOutput(_appCircuitOutput);

        // TODO: Reset all OG multipliers

        // Save OG multipliers on the corresponding pools
        for (uint256 i = 0; i < ogAddresses.length; i++) {
            address ogAddress = ogAddresses[i];
            address currency = currencies[i];
            uint256 amount = amounts[i];
            for (uint256 j = 0; j < offeringLengths[currency]; j++) {
                Offering storage offering = offerings[currency][j];
                if (amount >= offering.amount) {
                    ogMultipliers[ogAddress][offering.poolId] = offering.multiplier;
                }
            }
        }
    }

    function withdrawRewards(
        IncentiveHook.PositionParams calldata params,
        ERC20 rewardToken
    ) external {
        // Call IncentiveHook to withdraw rewards
        (uint256 rewards0, uint256 rewards1) = incentiveHook.withdrawRewards(
            params,
            rewardToken,
            msg.sender
        );
        uint256 totalRewards = rewards0 + rewards1;

        // Apply multiplier
        uint256 additionalRewards = totalRewards * ogMultipliers[msg.sender][params.poolId] / 10000;
        
        // Check and update reward balance
        require(rewardBalances[address(rewardToken)][params.poolId] >= additionalRewards, "Insufficient reward balance");
        rewardBalances[address(rewardToken)][params.poolId] -= additionalRewards;

        // Transfer additional rewards
        rewardToken.transfer(msg.sender, additionalRewards);

        emit RewardsWithdrawn(msg.sender, params.poolId, additionalRewards);
    }

    function decodeOutput(
        bytes calldata output
    ) internal pure returns (address[] memory, address[] memory, uint256[] memory) {
        uint256 numEntries = output.length / 72;
        address[] memory ogAddresses = new address[](numEntries);
        address[] memory tokenAddresses = new address[](numEntries);
        uint256[] memory amounts = new uint256[](numEntries);

        for (uint256 i = 0; i < numEntries; i++) {
            ogAddresses[i] = address(bytes20(output[i * 72: i * 72 + 20]));
            tokenAddresses[i] = address(bytes20(output[i * 72 + 20: i * 72 + 40]));
            amounts[i] = uint256(bytes32(output[i * 72 + 40: i * 72 + 72]));
        }

        return (ogAddresses, tokenAddresses, amounts);
    }

    function createOffering(Offering memory offering) external onlySponsor(offering.poolId) {
        offerings[offering.currency].push(offering);
        offeringLengths[offering.currency] += 1;

        emit OfferingCreated(offering.currency, offering.amount, offering.poolId, offering.multiplier);
    }

    function topupRewards(address currency, PoolId poolId, uint256 amount) external onlySponsor(poolId) {
        ERC20 rewardToken = ERC20(currency);
        rewardToken.transferFrom(msg.sender, address(this), amount);
        rewardBalances[currency][poolId] += amount;

        emit OfferingToppedUp(currency, amount, poolId);
    }
}
