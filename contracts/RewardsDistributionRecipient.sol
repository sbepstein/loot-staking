// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RewardsDistributionRecipient is Ownable {
    address public rewardsDistributor;

    function notifyRewardAmount(uint256 reward) virtual external;

    modifier onlyRewardsDistributor() {
        require(msg.sender == rewardsDistributor, "Caller is not RewardsDistribution contract");
        _;
    }

    function setRewardsDistributor(address _rewardsDistributor) external onlyOwner {
        rewardsDistributor = _rewardsDistributor;
    }
}
