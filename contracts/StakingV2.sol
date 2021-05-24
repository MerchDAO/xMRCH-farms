// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract StakingV2 {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint rewardOut;
    }

    mapping(address => Stake) public stakes;

    address public admin;

    address public stakeToken; // Uniswap LP token from pool MRCH|ETH:
    address public rewardToken; // MRCH token

    uint public stakingStart;
    uint public stakingEnd;
    uint public roundTime; // every round time in blocks, new reward amount
    uint public roundRewardAmount; // reward for each round

    uint public stakedTotal;

    event Staked(address staker, uint amount);
    event RewardOut(address staker, address token, uint amount);

    constructor(
        address stakeToken_,
        address rewardToken_,
        uint stakingStart_,
        uint stakingEnd_,
        uint roundTime_,
        uint roundRewardAmount_
    ) {
        admin = msg.sender;

        require(stakeToken_ != address(0), "MRCHStaking: stake token address is 0");
        stakeToken = stakeToken_;

        require(rewardToken_ != address(0), "MRCHStaking: reward token address is 0");
        rewardToken = rewardToken_;

        stakingStart = stakingStart_;

        require(stakingEnd_ > stakingStart, "MRCHStaking: staking end must be after staking start");
        stakingEnd = stakingEnd_;

        roundTime = roundTime_;

        require(roundRewardAmount > 0, "MRCHStaking: reward amount address is 0");
        roundRewardAmount = roundRewardAmount_;
    }

    function addReward(uint rewardAmount) public returns (bool) {
        require(rewardAmount > 0, "MRCHStaking: reward must be positive");

        doTransferIn(msg.sender, rewardToken, rewardAmount);

        return true;
    }

    function removeReward(address token, uint amount) public returns (bool) {
        require(msg.sender == admin, "MRCHStaking: Only admin can remove tokens from reward");

        doTransferOut(token, admin, amount);

        return true;
    }

    function stake(uint amount) public returns (bool) {
        require(amount > 0, "MRCHStaking: must be positive");
        require(getTimeStamp() >= stakingStart, "MRCHStaking: bad timing for the request");
        require(getTimeStamp() < stakingEnd, "MRCHStaking: bad timing for the request");

        address staker = msg.sender;

        doTransferIn(staker, stakeToken, amount);

        emit Staked(staker, amount);

        // Transfer is completed
        stakedTotal = stakedTotal.add(amount);
        stakes[staker].amount = stakes[staker].amount.add(amount);

        return true;
    }

    function withdraw() public returns (bool) {
        require(claimReward(), "MRCHStaking: claim error");
        uint amount = stakes[msg.sender].amount;

        return withdrawWithoutReward(amount);
    }

    function withdrawWithoutReward(uint amount) public returns (bool) {
        return withdrawInternal(msg.sender, amount);
    }

    function withdrawInternal(address staker, uint amount) internal returns (bool) {
        uint withdrawStart = stakingEnd.add(roundTime);

        require(getTimeStamp() >= withdrawStart, "MRCHStaking: bad timing for the request");
        require(amount > 0, "MRCHStaking: must be positive");
        require(amount <= stakes[msg.sender].amount, "MRCHStaking: not enough balance");

        stakes[staker].amount = stakes[staker].amount.sub(amount);

        doTransferOut(stakeToken, staker, amount);

        return true;
    }

    function claimReward() public returns (bool) {
        require(getTimeStamp() > stakingEnd, "MRCHStaking: bad timing for the request");

        address staker = msg.sender;

        uint rewardAmount = currentReward(staker);

        if (rewardAmount == 0) {
            return true;
        }

        doTransferOut(rewardToken, staker, rewardAmount);

        stakes[staker].rewardOut = stakes[staker].rewardOut.add(rewardAmount);

        emit RewardOut(staker, rewardToken, rewardAmount);

        return true;
    }

    function currentReward(address staker) public view returns (uint) {
        uint totalStakerReward = calcTotalReward(staker);
        uint timeStamp = getTimeStamp();

        if (totalStakerReward == 0 || timeStamp < stakingEnd) {
            return 0;
        }

        uint allTime = roundTime;
        uint withdrawStart = stakingEnd.add(roundTime);

        uint time = timeStamp < withdrawStart ? timeStamp.sub(stakingEnd) : allTime;

        uint stakerRewardToTimestamp = totalStakerReward.mul(time).div(allTime);
        uint rewardOut = stakes[staker].rewardOut;

        return stakerRewardToTimestamp.sub(rewardOut);
    }

    function calcTotalReward(address staker) public view returns (uint) {
        uint amount = stakes[staker].amount;

        return calcReward(amount);
    }

    function calcReward(uint amount) public view returns (uint) {
        uint rewardAmount = roundRewardAmount.mul(amount).div(stakedTotal);

        return rewardAmount;
    }

    function doTransferOut(address token, address to, uint amount) internal {
        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransfer(to, amount);
    }

    function doTransferIn(address from, address token, uint amount) internal {
        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransferFrom(from, address(this), amount);
    }

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }
}
