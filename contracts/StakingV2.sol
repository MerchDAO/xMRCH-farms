// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract StakingV3 is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint startTime;
        uint rewardOut;
    }

    mapping(uint => mapping(address => Stake)) public stakes;

    // Info of each pool.
    struct Pool {
        uint rewardAmount; // Pool reward tokens limit
        uint stakeStartTime;
        uint stakeEndTime;
        uint stakedTotal;
        uint roundTime;
    }

    Pool[] public pools;

    address public stakeToken; // Uniswap LP token from pool MRCH/USDT
    address public rewardToken; // MRCH token

    event Staked(uint pid, address staker, uint amount);
    event RewardOut(uint pid, address staker, address token, uint amount);

    constructor(
        address stakeToken_,
        address rewardToken_
    ) {
        require(stakeToken_ != address(0), "MRCHStaking: stake token address is 0x0");
        stakeToken = stakeToken_;

        require(rewardToken_ != address(0), "MRCHStaking: reward token address is 0x0");
        rewardToken = rewardToken_;
    }

    function addPool(uint rewardAmount_, uint startTime_, uint endTime_, uint roundTime_) public onlyOwner {
        require(getTimeStamp() <= startTime_, "MRCHStaking: bad timing for the request");
        require(startTime_ < endTime_, "MRCHStaking: endTime > startTime");

        doTransferIn(msg.sender, rewardToken, rewardAmount_);

        pools.push(
            Pool({
            rewardAmount: rewardAmount_,
            stakeStartTime: startTime_,
            stakeEndTime: endTime_,
            roundTime: roundTime_,
            stakedTotal: 0
            })
        );
    }

    function stake(uint pid, uint amount) public returns (bool) {
        require(amount > 0, "MRCHStaking: amount must be positive");
        require(getTimeStamp() >= pools[pid].stakeStartTime, "MRCHStaking: bad timing for the request");
        require(getTimeStamp() < pools[pid].stakeEndTime, "MRCHStaking: bad timing for the request");

        address staker = msg.sender;

        doTransferIn(staker, stakeToken, amount);

        // Transfer is completed
        pools[pid].stakedTotal = pools[pid].stakedTotal.add(amount);

        stakes[pid][staker].amount = stakes[pid][staker].amount.add(amount);
        stakes[pid][staker].startTime = getTimeStamp();

        emit Staked(pid, staker, amount);

        return true;
    }

    function withdraw(uint pid) public returns (bool) {
        require(claim(pid), "MRCHStaking: claim error");

        uint amount = stakes[pid][msg.sender].amount;

        return withdrawWithoutReward(pid, amount);
    }

    function withdrawWithoutReward(uint pid, uint amount) public returns (bool) {
        return withdrawInternal(pid, msg.sender, amount);
    }

    function withdrawInternal(uint pid, address staker, uint amount) internal returns (bool) {
        require(amount > 0, "MRCHStaking: amount must be positive");
        require(amount <= stakes[pid][msg.sender].amount, "MRCHStaking: not enough balance");

        uint withdrawTime = pools[pid].stakeEndTime.add(pools[pid].roundTime);
        require(getTimeStamp() > withdrawTime, "MRCHStaking: bad timing for the request");

        stakes[pid][staker].amount = stakes[pid][staker].amount.sub(amount);

        doTransferOut(stakeToken, staker, amount);

        return true;
    }

    function claim(uint pid) public returns (bool) {
        uint claimTime = pools[pid].stakeEndTime.add(pools[pid].roundTime);

        require(getTimeStamp() > claimTime, "MRCHStaking: bad timing for the request");

        address staker = msg.sender;

        uint rewardAmount = currentReward(pid, staker);

        if (rewardAmount == 0) {
            return true;
        }

        doTransferOut(rewardToken, staker, rewardAmount);

        stakes[pid][staker].rewardOut = stakes[pid][staker].rewardOut.add(rewardAmount);

        emit RewardOut(pid, staker, rewardToken, rewardAmount);

        return true;
    }

    function currentReward(uint pid, address staker) public view returns (uint) {
        uint totalRewardAmount = pools[pid].rewardAmount;
        uint stakedTotal = pools[pid].stakedTotal;

        uint amount = stakes[pid][staker].amount;
        uint rewardOut = stakes[pid][staker].rewardOut;

        uint rewardAmount = totalRewardAmount.mul(amount).div(stakedTotal);

        return rewardAmount.sub(rewardOut);
    }

    function doTransferOut(address token, address to, uint amount) internal {
        if (amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransfer(to, amount);
    }

    function doTransferIn(address from, address token, uint amount) internal {
        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransferFrom(from, address(this), amount);
    }

    function transferTokens(address token, address to, uint amount) public onlyOwner {
        doTransferOut(token, to, amount);
    }

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }
}
