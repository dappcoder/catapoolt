# CataPOOLt

A Uniswap V4 (hook) based protocol for incentivising LPs to provide liquidity.

Ideal for kickstarting projects by attracting liquidity to desired token pairs.

## Features

Catapoolt has four main liquidity incentivisation features:
1. Liquidity mining for V4: Catapoolt uses PoolManager state to calculate the fees earned by LPs and to distribute rewards proportionally to the earned amounts.  
```
forge test --match-test test_demo_liquidityMining
```

2. Brevis OG Multiplier: Multiplied rewards to OG LPs that earned lots of fees on external pools or AMMs. The sponsor sets up reward multipliers for pools with farming rewards. The list of the top LPs is aggregated by an off-chain Brevis based service. The ZK circuit proves that the OG list is authentic.
```
forge test --match-test test_demo_BrevisOgMultiplier
```

3. Rewards to top weekly LPs: Introduces gamification based on a LP competition. Weekly prize tokens are awarded to the top LPs. LPs can register for the competition and after a week, based on the amounts of fees earned, they can win prizes based on their rankings.
```
forge test --match-test test_demo_LpCompoetitionTopPrizes
```

4. Dynamic Fee Distribution: Unlike dynamic fees, all swappers pay the same amount of fees. The "dynamic" term is related to the distribution of fees. Top LPs from the previous week's competition will earn more fee. How it works: All swappers that registered to the weekly competition will earn say 90% of the swapping fee allocation. The remaining 10% are retained in the hook contract. After the competition ends, the top LPs will split the retained fees from the last week. Fees are cumulated in the Hook contract.
```
forge test --match-test test_demo_LpCompetitionDynamicFeeDistribution
```
