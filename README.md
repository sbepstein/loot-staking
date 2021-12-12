# Loot staking rewards

🚨 This repo is still a work-in-progress. Comments, feedback, questions, etc. are welcomed and encouraged.

## What is this?

Loot holders can stake their Loot to earn [$AGLD](https://etherscan.io/token/0x32353a6c91143bfd6c7d363b546e62a9a2489a20) rewards.

Loot staking is designed using a fixed lockup duration with fixed rewards. The rewards are claimable in full after the duration. However, the staking contract does not custody the Loot tokens. This is to allow for Loot holders to stake while still holding their Loot for gameplay.

## How it works (as a staker)

As a holder of a Loot token, you may choose a staking option which is a duration and reward amount. At the end of the duration, you may claim the rewards in full.

If you sell your Loot that is staked, you cannot claim those rewards anymore. The new owner may stake their new Loot and that will erase your staking claim.

## How it works (as a deployer)

1. Deploy the contract with parameters specifying: account, appropriate Loot staking token address, reward token address, and staking options you want to initialize.
2. Send the reward token to the Staking contract.
3. From the admin account, call `notifyRewardAmount()` with the amount of rewards added.

## Resources

- [Loot staking tweet chain](https://twitter.com/WillPapper/status/1467357820399980546)
- [AGLD tokenomics discussion](https://loot-talk.com/t/adventure-gold-tokenomics-proposal-v1/1156)

## Disclaimer

_Use at your own risk. NFA. DYOR._
