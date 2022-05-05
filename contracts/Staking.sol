// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Staking__TransferFailed();
error Staking__NeedsMoreThanZero();

contract Staking {
    IERC20 public s_stakingToken; // "s" indicates that it's a storage var (expensive to r & w)
    IERC20 public s_rewardToken;
    
    uint256 public constant REWARD_RATE = 100;
    uint256 public s_totalSupply; // keeps track of how much token we have in total
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;

    mapping(address => uint256) public s_balances; // someone's address -> how much they staked
    mapping(address => uint256) public s_userRewardPerTokenPaid; // how much each address has been paid
    mapping(address => uint256) public s_rewards; // how much rewards each address has

    modifier updateReward(address _account) {
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = block.timestamp;
        s_rewards[_account] = earned(_account);
        s_userRewardPerTokenPaid[_account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 _amount) {
        if(_amount == 0) {
            revert Staking__NeedsMoreThanZero();
        }
        _;
    } 

    constructor(address _stakingToken, address _rewardToken) {
        s_stakingToken = IERC20(_stakingToken);
        s_rewardToken = IERC20(_rewardToken);
    }

    function earned(address _account) public view returns (uint256) {
        uint256 currentBalance = s_balances[_account];

        uint256 amountPaid = s_userRewardPerTokenPaid[_account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[_account];

        uint256 totalEarned = ((currentBalance * (currentRewardPerToken - amountPaid)) / 1e18) + pastRewards;

        return totalEarned;
    }

    /// @dev Calculates reward based on how long it's been during this most recent snapshot
    function rewardPerToken() public view returns (uint256) {
        if(s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        }

        return s_rewardPerTokenStored + (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply);
    }

    /// @dev locks tokens into the contract
    /// TODO: if we want to allow any tokens then we can use chainlink to convert prices between tokens
    function stake(uint256 _amount) external updateReward(msg.sender) moreThanZero(_amount) {
        s_balances[msg.sender] += _amount;
        s_totalSupply += _amount;

        bool success = s_stakingToken.transferFrom(msg.sender, address(this), _amount);

        if(!success) {
            revert Staking__TransferFailed();
        }
    }

    /// @dev unlocks tokens and pulls them out of the contract
    function withdraw(uint256 _amount) external updateReward(msg.sender) moreThanZero(_amount) {
        s_balances[msg.sender] -= _amount;
        s_totalSupply -= _amount;

        bool success = s_stakingToken.transfer(msg.sender, _amount);
    }

    /// @dev allows users to claim their reward tokens
    ///     what's a good reward mechanism
    ///     what's some good reward math
    function claimReward() external updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];

        bool success = s_rewardToken.transfer(msg.sender, reward);

        if(!success) {
            revert Staking__TransferFailed();
        }
    }   

}
