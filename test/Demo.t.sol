// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

import {IncentiveHook} from "../src/IncentiveHook.sol";
import {OGMultiplier} from "../src/OGMultiplier.sol";
import {LPCompetition} from "../src/LPCompetition.sol";
import {MockBrevisProof} from "./utils/MockBrevisProof.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract Demo is Test, Deployers {

    using CurrencyLibrary for Currency;

    using PoolIdLibrary for PoolKey;

    MockERC20 token0;

    MockERC20 token1;

	MockERC20 rewardToken;

    Currency tokenCurrency0;

    Currency tokenCurrency1;

	Currency rewardCurrency;

    PoolManager mngr;

    PoolKey poolKey;

    PoolId poolId;

    IncentiveHook hook;

    OGMultiplier ogMultiplier;

    LPCompetition lpCompetition;

    address alice;

    address bob;

    address carol;

    address david;
    
    address erica;

    function setUp() public {
        deployFreshManagerAndRouters();

        console.log("This test              address: %s", address(this));
        console.log("Manager                address: %s", address(manager));
        console.log("SwapRouter             address: %s", address(swapRouter));
        console.log("ModifyLiquidityRouter  address: %s", address(modifyLiquidityRouter));

        mngr = PoolManager(address(manager));

        token0 = new MockERC20("Test Token 1", "TST1", 18);
        tokenCurrency0 = Currency.wrap(address(token0));
        token0.mint(address(this), 1_000_000 ether);

        token1 = new MockERC20("Test Token 2", "TST2", 18);
        tokenCurrency1 = Currency.wrap(address(token1));
        token1.mint(address(this), 1_000_000 ether);

		rewardToken = new MockERC20("Reward Token", "REW", 18);
		rewardCurrency = Currency.wrap(address(rewardToken));
		rewardToken.mint(address(this), 50_000_000 ether);

        address hookAddress = address(
            uint160(
                Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
                Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG | 
                Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG
            )
        );

        deployCodeTo("IncentiveHook.sol", abi.encode(manager), hookAddress);

        hook = IncentiveHook(hookAddress);

        token0.approve(address(swapRouter), type(uint256).max);
        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);

        (poolKey, poolId) = initPool(
            tokenCurrency0,
            tokenCurrency1,
            hook,
            3000,
            Constants.SQRT_PRICE_1_1,
            ZERO_BYTES
        );

        MockBrevisProof brevisProof = new MockBrevisProof();
        ogMultiplier = new OGMultiplier(address(hook), brevisProof);
        lpCompetition = new LPCompetition(address(hook), address(modifyLiquidityRouter));

        alice = address(0x1);
        bob = address(0x2);
        carol = address(0x3);
        david = address(0x4);
        erica = address(0x5);
    }



    ////////////////////////
    /// LIQUIDITY MINING ///
    ////////////////////////

    function test_demo_liquidityMining() public {

        // Sponsor adds mining rewards
        rewardToken.approve(address(hook), type(uint256).max);
        hook.updateRewards(poolId, rewardToken, 1 ether, 100);

        // Alice adds liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -120,
            tickUpper: 120,
            liquidityDelta: 10 ether,
            salt: bytes32(uint256(0))     // Alice's salt
        }), ZERO_BYTES);

        // Bob adds liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 5 ether,
            salt: bytes32(uint256(1))     // Bob's salt
        }), ZERO_BYTES);

        // Carol adds liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(uint256(2))     // Carol's salt
        }), ZERO_BYTES);

        // Swap to generate fees
        swapRouter.swap(poolKey, IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }), PoolSwapTest.TestSettings({
            settleUsingBurn: false,
            takeClaims: false
        }), ZERO_BYTES);

        // 10 blocks pass
        vm.roll(10);

        // Alice pokes the pool and claims rewards
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams(-120, 120, 0 ether, bytes32(uint256(0))), ZERO_BYTES, false, false);
        (uint256 aliceRewards0, uint256 aliceRewards1) = hook.withdrawRewards(IncentiveHook.PositionParams({
            poolId: poolId,
            owner: address(modifyLiquidityRouter),
            tickLower: -120,
            tickUpper: 120,
            salt: bytes32(uint256(0)) // Alice's salt
        }), rewardToken, address(this));

        // Bob pokes the pool and claims rewards
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 0 ether, bytes32(uint256(1))), ZERO_BYTES, false, false);
        (uint256 bobRewards0, uint256 bobRewards1) = hook.withdrawRewards(IncentiveHook.PositionParams({
            poolId: poolId,
            owner: address(modifyLiquidityRouter),
            tickLower: -60,
            tickUpper: 60,
            salt: bytes32(uint256(1)) // Bob's salt
        }), rewardToken, address(this));

        // Carol pokes the pool and claims rewards
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 0 ether, bytes32(uint256(2))), ZERO_BYTES, false, false);
        (uint256 carolRewards0, uint256 carolRewards1) = hook.withdrawRewards(IncentiveHook.PositionParams({
            poolId: poolId,
            owner: address(modifyLiquidityRouter),
            tickLower: -60,
            tickUpper: 60,
            salt: bytes32(uint256(2)) // Carol's salt
        }), rewardToken, address(this));

        // Bob and Carol have the same amount of rewards 
        assertEq(bobRewards0, 2.5 ether);
        assertEq(carolRewards0, 2.5 ether);

        // Alice has twice as much.
        assertEq(aliceRewards0, 5 ether);
    }


    
    ////////////////////////////
    /// BREVIS OG MULTIPLIER ///
    ////////////////////////////

    function test_demo_BrevisOgMultiplier() public {

        // Sponsor adds mining rewards
        rewardToken.approve(address(hook), type(uint256).max);
        hook.updateRewards(poolId, rewardToken, 1 ether, 100);

        // Sponsor sets up multiplier for the pool
        ogMultiplier.createOffering(OGMultiplier.Offering({
            currency: Currency.unwrap(currency0),
            amount: 100_000 ether,
            poolId: poolId,
            multiplier: 5000 // 5000 bps => 50%
        }));

        // Sponsor tops up multiplier rewards
        rewardToken.approve(address(ogMultiplier), type(uint256).max);
        ogMultiplier.topupRewards(address(rewardToken), poolId, 50 ether);

        // Alice qualifies as an OG liquidity provider (according to Brevis proof)
        bytes memory data = new bytes(32);
        assembly {
            mstore(add(data, 32), 0) // store the 0 value at the memory location
        }
        ogMultiplier.handleProofResult(bytes32(0), bytes32(0), data);

        // 10 blocks pass
        vm.roll(10);

        // Alice adds liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(uint256(0))     // Alice's salt
        }), ZERO_BYTES);

        // Bob adds liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(uint256(1))     // Bob's salt
        }), ZERO_BYTES);

        // Swap to generate fees
        swapRouter.swap(poolKey, IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }), PoolSwapTest.TestSettings({
            settleUsingBurn: false,
            takeClaims: false
        }), ZERO_BYTES);

        // Alice pokes the pool and claims rewards
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 0 ether, bytes32(uint256(0))), ZERO_BYTES, false, false);
        (uint256 aliceTotal, uint256 aliceAdditional) = ogMultiplier.withdrawRewards(IncentiveHook.PositionParams({
            poolId: poolId,
            owner: address(modifyLiquidityRouter),
            tickLower: -60,
            tickUpper: 60,
            salt: bytes32(uint256(0)) // Alice's salt
        }), rewardToken);

        // Bob pokes the pool and claims rewards
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 0 ether, bytes32(uint256(1))), ZERO_BYTES, false, false);
        (uint256 bobTotal, uint256 bobAdditional) = ogMultiplier.withdrawRewards(IncentiveHook.PositionParams({
            poolId: poolId,
            owner: address(modifyLiquidityRouter),
            tickLower: -60,
            tickUpper: 60,
            salt: bytes32(uint256(1)) // Bob's salt
        }), rewardToken);

        // Alice has 50% more rewards than Bob beacuse of the multiplier
        assertEq(aliceTotal, 7.5 ether);
        assertEq(bobTotal, 5 ether);
        assertEq(aliceAdditional, 2.5 ether);
        assertEq(bobAdditional, 0 ether);
    }



    ///////////////////////////////////
    /// LP COMPETITION - TOP PRIZES ///
    ///////////////////////////////////

    function test_demo_LpCompoetitionTopPrizes() public {

        // Sponsor creates LP competition (top 3 will earn prizes)
        uint256[] memory prizes = new uint256[](3);
        prizes[0] = 10 ether;
        prizes[1] = 5 ether;
        prizes[2] = 2.5 ether;
        uint256 competitionId = lpCompetition.createCompetition(poolKey, address(rewardToken), prizes);

        // Sponsor deposits prize tokens
        rewardToken.approve(address(lpCompetition), type(uint256).max);
        lpCompetition.depositRewards(1);

        // Alice, Bob, Carol, David and Erica add descending amounts of liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(uint256(0))     // Alice's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 9 ether,
            salt: bytes32(uint256(1))     // Bob's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 8 ether,
            salt: bytes32(uint256(2))     // Carol's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 7 ether,
            salt: bytes32(uint256(3))     // David's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 6 ether,
            salt: bytes32(uint256(4))     // Erica's salt
        }), ZERO_BYTES);

        // Alice, Bob, Carol, David and Erica join the competition
        lpCompetition.registerForCompetition(alice, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(0))     // Alice's salt
        }));
        lpCompetition.registerForCompetition(bob, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(1))     // Bob's salt
        }));
        lpCompetition.registerForCompetition(carol, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(2))     // Carol's salt
        }));
        lpCompetition.registerForCompetition(david, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(3))     // David's salt
        }));
        lpCompetition.registerForCompetition(erica, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(4))     // Erica's salt
        }));

        // Swap to generate fees
        swapRouter.swap(poolKey, IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }), PoolSwapTest.TestSettings({
            settleUsingBurn: false,
            takeClaims: false
        }), ZERO_BYTES);

        // Almost 1 week later
        uint256 secondsInAWeek = 7 * 24 * 60 * 60;
        uint256 adjustment = 100;
        uint256 divisor = 12;
        uint256 blockNumber = (secondsInAWeek - adjustment) / divisor;
        vm.roll(blockNumber);

        // Alice, Bob, Carol, David and Erica end participation
        lpCompetition.endParticipation(alice, competitionId);
        lpCompetition.endParticipation(bob, competitionId);
        lpCompetition.endParticipation(carol, competitionId);
        lpCompetition.endParticipation(david, competitionId);
        lpCompetition.endParticipation(erica, competitionId);

        // TODO embed in first endParticipation call ???
        lpCompetition.calculateRankings(competitionId);

        // 1 week+ later (competition ended)
        blockNumber = (secondsInAWeek - adjustment) / divisor;
        vm.roll(blockNumber);

        // Alice, Bob, Carol, David and Erica mint SBT rank badges
        lpCompetition.mintSoulboundToken(alice, competitionId);
        lpCompetition.mintSoulboundToken(bob, competitionId);
        lpCompetition.mintSoulboundToken(carol, competitionId);
        lpCompetition.mintSoulboundToken(david, competitionId);
        lpCompetition.mintSoulboundToken(erica, competitionId);

        // Alice, Bob, Carol claim prizes
        assertEq(lpCompetition.claimPrize(alice, competitionId), 10 ether);
        assertEq(lpCompetition.claimPrize(bob, competitionId), 5 ether);
        assertEq(lpCompetition.claimPrize(carol, competitionId), 2.5 ether);

        // David and Erica did not make it to the top 3. No prizes for them.
        assertEq(lpCompetition.claimPrize(david, competitionId), 0 ether);
        assertEq(lpCompetition.claimPrize(erica, competitionId), 0 ether);
    }



    /////////////////////////////////////////////////
    /// LP COMPETITION - DYNAMIC FEE DISTRIBUTION ///
    /////////////////////////////////////////////////

    function test_demo_LpCompetitionDynamicFeeDistribution() public {

        // Alice, Bob, Carol, David and Erica add descending amounts of liquidity
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(uint256(0))     // Alice's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 9 ether,
            salt: bytes32(uint256(1))     // Bob's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 8 ether,
            salt: bytes32(uint256(2))     // Carol's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 7 ether,
            salt: bytes32(uint256(3))     // David's salt
        }), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(poolKey, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 6 ether,
            salt: bytes32(uint256(4))     // Erica's salt
        }), ZERO_BYTES);

        // Sponsor creates LP competition (top 3 will earn prizes)
        uint256[] memory prizes = new uint256[](3);
        prizes[0] = 0 ether;
        prizes[1] = 0 ether;
        prizes[2] = 0 ether;
        uint256 competitionId = lpCompetition.createCompetition(poolKey, address(rewardToken), prizes);        

        // Alice, Bob, Carol, David and Erica join the competition
        lpCompetition.registerForCompetition(alice, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(0))     // Alice's salt
        }));
        lpCompetition.registerForCompetition(bob, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(1))     // Bob's salt
        }));
        lpCompetition.registerForCompetition(carol, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(2))     // Carol's salt
        }));
        lpCompetition.registerForCompetition(david, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(3))     // David's salt
        }));
        lpCompetition.registerForCompetition(erica, competitionId, IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 0 ether,
            salt: bytes32(uint256(4))     // Erica's salt
        }));

        // Registration window closes
        uint256 secondsInADay = 24 * 60 * 60;
        uint256 adjustment = 1000;
        uint256 blockDuration = 12;
        uint256 blockNumber = (secondsInADay - adjustment) / blockDuration;
        vm.roll(blockNumber);

        // Swap to generate fees
        swapRouter.swap(poolKey, IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -1 ether,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }), PoolSwapTest.TestSettings({
            settleUsingBurn: false,
            takeClaims: false
        }), ZERO_BYTES);

        // Almost 1 week later 
        uint256 secondsInAWeek = 7 * 24 * 60 * 60;
        adjustment = 100;
        uint256 divisor = 12;
        blockNumber = (secondsInAWeek - adjustment) / divisor;
        vm.roll(blockNumber);

        // Alice, Bob, Carol, David and Erica end participation
        lpCompetition.endParticipation(alice, competitionId);
        lpCompetition.endParticipation(bob, competitionId);
        lpCompetition.endParticipation(carol, competitionId);
        lpCompetition.endParticipation(david, competitionId);
        lpCompetition.endParticipation(erica, competitionId);

        // TODO embed in first endParticipation call ???
        lpCompetition.calculateRankings(competitionId);

        // 1 week+ later (competition ended)
        blockNumber = (secondsInAWeek - adjustment) / divisor;
        vm.roll(blockNumber);

        // Alice, Bob, Carol, David and Erica mint SBT rank badges
        lpCompetition.mintSoulboundToken(alice, competitionId);
        lpCompetition.mintSoulboundToken(bob, competitionId);
        lpCompetition.mintSoulboundToken(carol, competitionId);
        lpCompetition.mintSoulboundToken(david, competitionId);
        lpCompetition.mintSoulboundToken(erica, competitionId);

        // Everyone earned 10% less fees
        uint256 aliceFees = lpCompetition.getLPInfo(competitionId, alice).endFees;
        uint256 bobFees = lpCompetition.getLPInfo(competitionId, bob).endFees;
        uint256 carolFees = lpCompetition.getLPInfo(competitionId, carol).endFees;
        uint256 davidFees = lpCompetition.getLPInfo(competitionId, david).endFees;
        uint256 ericaFees = lpCompetition.getLPInfo(competitionId, erica).endFees;

        assertEq(aliceFees, 0.0054 ether);
        assertEq(bobFees, 0.0054 ether);
        assertEq(carolFees, 0.0054 ether);
        assertEq(davidFees, 0.0054 ether);
        assertEq(ericaFees, 0.0054 ether);

        // Alice, Bob and Carol claim retained fees.
        uint256 aliceExtra = lpCompetition.claimExtraFees(alice, competitionId);
        uint256 bobExtra = lpCompetition.claimExtraFees(bob, competitionId);
        uint256 carolExtra = lpCompetition.claimExtraFees(carol, competitionId);
        assertEq(aliceExtra, 0.001 ether);
        assertEq(bobExtra, 0.001 ether);
        assertEq(carolExtra, 0.001 ether);

        // David and Erica have no fees to claim.
        uint256 davidExtra = lpCompetition.claimExtraFees(david, competitionId);
        uint256 ericaExtra = lpCompetition.claimExtraFees(erica, competitionId);
        assertEq(davidExtra, 0);
        assertEq(ericaExtra, 0);
    }
}
