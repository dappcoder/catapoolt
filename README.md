# CataPOOLt

A Uniswap V4 (hook) based protocol for incentivising LPs to provide liquidity.

Ideal for kickstarting projects by attracting liquidity to desired token pairs.

## Features

### Liquidity mining rewards
Sponsor configures and deposits/withdraws rewards for the desired number of blocks.

Rewards are calculated proportionally to the fees earned by LPs. 
If no fees were generated during a certain period of time, the rewards are devided equally to the LPs that had liquidity around the last tick.

LPs withdraw rewards.


### Weekly soulbound tokens for top LPs
Top LPs for a pool are determined every week for the past week using Brevis.

Brevis handler function mints soulbound tokens to top N(configurable) LPs.

Soulbound token attributes:
* Week 
* Rank
* Pool ID


### Prizes for top LPs
#### Configure ERC20 prizes
#### Configure NFT prizes
#### Claim ERC20 prizes
#### Claim NFT prizes
#### Reclaim unallocated prizes 


### Dynamic fee allocation for top LPs
#### Configure distribution
#### Apply dynamic fee allocation


### Vesting
#### Configure vesting rewards
#### Configure vesting prizes
#### Withdraw rewards
#### Withdraw prizes


### Brevis switch


### Protocol fee with switch


### Autocompounding
Configured by LP (enabled means rewards are added to a desired position)
Triggered by LP update operations
Triggered externally
