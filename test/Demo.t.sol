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

    IncentiveHook hook;

    PoolManager mngr;

    PoolKey poolKey;

    PoolId poolId;

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
    }

    function test_demo_liquidityMining() public {
        console.log("Liquidity Mining Test");

        // Sponsor adds mining rewards

        // 10 blocks pass

        // Alice adds liquidity

        // Bob adds liquidity

        // Carol adds liquidity

        // Swap to generate fees

        // Alice pokes the pool and claims rewards

        // Bob pokes the pool and claims rewards

        // Carol pokes the pool and claims rewards

        // Alice and Bob have the same amount of rewards 
        
        // Carol has twice as much.
    }

    function test_demo_BrevisOgMultiplier() public {
        console.log("Brevis Og Multiplier Test");        

        // Sponsor adds mining rewards

        // Sponsor sets up multiplier for the pool

        // Sponsor tops up multiplier rewards

        // Alice qualifies as an OG liquidity provider (according to Brevis proof)

        // 10 blocks pass

        // Alice adds liquidity

        // Bob adds liquidity

        // Swap to generate fees

        // Alice pokes the pool and claims rewards

        // Bob pokes the pool and claims rewards

        // Alice has 50% more rewards than Bob beacuse of the multiplier
    }

    function test_demo_LpCompoetitionTopPrizes() public {
        console.log("Lp Competition - Top Prizes Test");

        // Sponsor creates LP competition (top 3 will earn prizes)

        // Sponsor deposits prize tokens

        // Alice, Bob, Carol, David and Erica add descending amounts of liquidity

        // Alice, Bob, Carol, David and Erica join the competition

        // Swap to generate fees

        // Almost 1 week later

        // Alice, Bob, Carol, David and Erica end participation

        // 1 week+ later (competition ended)

        // Alice, Bob, Carol, David and Erica mint SBT rank badges

        // Alice, Bob, Carol claim prizes

        // David and Erica did not make it to the top 3. No prizes for them.
    }

    function test_demo_LpCompetitionDynamicFeeDistribution() public {
        console.log("Lp Competition - Dynamic Fee Distribution Test");

        // Sponsor creates LP competition (top 3 will earn prizes)

        // Alice, Bob, Carol, David and Erica add descending amounts of liquidity

        // Alice, Bob, Carol, David and Erica join the competition

        // Swap to generate fees

        // Almost 1 week later 

        // Alice, Bob, Carol, David and Erica end participation

        // 1 week+ later (competition ended)

        // Alice, Bob, Carol, David and Erica mint SBT rank badges

        // Swap in week 2 generates fees

        // David and Erica earn 10% less fees than paid by swapper.

        // Alice, Bob and Carol claim the fees retained from David and Erica.
    }
}