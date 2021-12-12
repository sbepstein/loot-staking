// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./RewardsDistributionRecipient.sol";

/**
 * @title Loot staking rewards contract
 * @notice Staking is on a fixed time basis with a fixed reward amount.
 * @dev This contract should be topped up with the rewards token before notifying of rewards.
 * @author Gary Thung
 */
contract LootStakingRewards is RewardsDistributionRecipient, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct StakingOption {
        bool isActive;
        uint256 reward;
        uint256 duration;
    }

    struct StakingData {
        address staker;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
    }

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC721 public stakingToken;

    mapping(address => uint256) public rewards;

    mapping(uint256 => StakingData) public staked; // Loot token ID => stake data

    uint256 private _rewardsLocked; // amount of rewards due to stakers
    uint256 private _rewardSupply; // amount of rewards in the contract
    mapping(uint256 => StakingOption) private _stakingOptions;
    uint256 private _totalStakingOptions;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _rewardsDistributor The account that can modify the staking options and notify of available rewards
     * @param _rewardsToken ERC20 token given as rewards
     * @param _stakingToken ERC721 token that can be staked
     * @param _optionsRewards Staking options to initialize; pairs with durations
     * @param _optionsDurations Staking durations to initialize; pairs with rewards
     */
    constructor(
        address _rewardsDistributor,
        address _rewardsToken,
        address _stakingToken,
        uint256[] memory _optionsRewards,
        uint256[] memory _optionsDurations
    ) {
        rewardsDistributor = _rewardsDistributor;
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC721(_stakingToken);

        // Initialize staking options
        for (uint256 i = 0; i < _optionsRewards.length; i++) {
            _addStakingOption(_optionsRewards[i], _optionsDurations[i]);
        }
    }

    /* ========== VIEWS ========== */

    function rewardSupply() external view returns (uint256) {
        return _rewardSupply;
    }

    function rewardsLocked() external view returns (uint256) {
        return _rewardsLocked;
    }

    function rewardsAvailable() public view returns (uint256) {
        return _rewardSupply - _rewardsLocked;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 _tokenId, uint256 _optionId) external nonReentrant whenNotPaused {
        _stake(_tokenId, _optionId);
    }

    function unstake(uint256 _tokenId) external nonReentrant whenNotPaused onlyLootOwner(_tokenId) {
        _clearStakeData(_tokenId);
    }

    function claim(uint256 _tokenId) external nonReentrant whenNotPaused {
        _claim(_tokenId);
    }

    function bulkStake(uint256[] memory _tokenIds, uint256[] memory _optionIds) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _stake(_tokenIds[i], _optionIds[i]);
        }
    }

    function bulkUnstake(uint256[] memory _tokenIds) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(msg.sender == stakingToken.ownerOf(_tokenIds[i]), "ERR_NOT_LOOT_OWNER");
            _clearStakeData(_tokenIds[i]);
        }
    }

    function bulkClaim(uint256[] memory _tokenIds) external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _claim(_tokenIds[i]);
        }
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * Delete the staking data for a given token ID.
     *
     * @param _tokenId The token ID to clear.
     */
    function _clearStakeData(uint256 _tokenId) private {
        StakingData memory existingData = staked[_tokenId];

        // Clear old stake if it exists
        if (existingData.staker != address(0)) {
            _rewardsLocked -= existingData.amount;
            delete staked[_tokenId];
            emit Unstaked(msg.sender, existingData.staker, _tokenId);
        }
    }

    /**
     * Adds a new staking option tier.
     *
     * @param _reward The amount of reward tokens given for staking
     * @param _duration How long until the rewards are claimable
     */
    function _addStakingOption(uint256 _reward, uint256 _duration) private {
        require(_reward != 0, "ERR_REWARD_ZERO");
        require(_duration != 0, "ERR_DURATION_ZERO");
        _stakingOptions[_totalStakingOptions] = StakingOption(true, _reward, _duration);
        _totalStakingOptions += 1;
        emit StakingOptionAdded(_reward, _duration);
    }

    /**
     * Stakes a Loot token. Only callable by the current token owner.
     *
     * @param _tokenId The Loot token ID to stake
     * @param _optionId The staking option ID to use
     */
    function _stake(uint256 _tokenId, uint256 _optionId) private onlyLootOwner(_tokenId) {
        _clearStakeData(_tokenId);

        // Fetch staking option data
        StakingOption memory option = _stakingOptions[_optionId];
        require(option.isActive, "ERR_STAKING_OPTION_INACTIVE");
        require(rewardsAvailable() - option.reward >= 0, "ERR_REWARD_SUPPLY_TOO_LOW");

        // Set staking state for this token
        _rewardsLocked += option.reward;
        staked[_tokenId] = StakingData(msg.sender, option.reward, block.timestamp, block.timestamp + option.duration);

        emit Staked(msg.sender, _tokenId, _optionId);
    }

    /**
     * Claims rewards for a staked Loot. Only valid if the caller is the original
     * staker and the current token owner.
     *
     * @param _tokenId The Loot token ID to claim rewards for
     */
    function _claim(uint256 _tokenId) private onlyLootOwner(_tokenId) {
        StakingData memory data = staked[_tokenId];

        require(data.staker == msg.sender, "ERR_SENDER_NOT_STAKER");
        require(block.timestamp >= data.endTime, "ERR_CLAIM_TOO_SOON");

        // Update balances
        _rewardsLocked -= data.amount;
        _rewardSupply -= data.amount;

        // Delete staking data
        delete staked[_tokenId];

        // Transfer staking rewards
        rewardsToken.transfer(msg.sender, data.amount);

        emit Claimed(msg.sender, _tokenId, data.amount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * Increases the available rewards supply. Only callable by the rewards
     * distributor.
     *
     * @param _amount Additional rewards now avilable
     */
    function notifyRewardAmount(uint256 _amount) override external onlyRewardsDistributor {
        _rewardSupply += _amount;
        emit RewardsAdded(_amount);
    }

    /**
     * External function for adding a new staking option tier. Only callable by
     * the rewards distributor.
     *
     * @param _reward The amount of reward tokens given for staking
     * @param _duration How long until the rewards are claimable
     */
    function addStakingOption(uint256 _reward, uint256 _duration) external onlyRewardsDistributor {
        _addStakingOption(_reward, _duration);
    }

    /**
     * Disables a staking rewards tier. Only callable by the rewards distributor.
     *
     * @param _optionId Staking option to disable
     */
    function disableStakingOption(uint256 _optionId) external onlyRewardsDistributor {
        StakingOption memory option = _stakingOptions[_optionId];
        require(option.isActive, "ERR_STAKING_OPTION_INACTIVE");
        _stakingOptions[_optionId].isActive = false;
        emit StakingOptionDisabled(_optionId);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyLootOwner(uint256 _tokenId) {
        require(msg.sender == stakingToken.ownerOf(_tokenId), "ERR_NOT_LOOT_OWNER");
        _;
    }

    /* ========== EVENTS ========== */

    event RewardsAdded(uint256 reward);
    event Staked(address indexed user, uint256 tokenId, uint256 optionId);
    event Unstaked(address indexed unstaker, address indexed staker, uint256 tokenId);
    event Withdrawn(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 tokenId, uint256 amount);
    event StakingOptionAdded(uint256 reward, uint256 duration);
    event StakingOptionDisabled(uint256 optionId);
}
