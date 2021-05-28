// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract StakingV2 is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint startTime;
        uint fraction;
        uint rewardOut;
    }

    mapping(uint => mapping(address => Stake)) public stakes;

    // Info of each pool.
    struct Pool {
        uint rewardAmount; // Pool reward tokens limit
        uint startTime;
        uint endTime;
        uint total;
        uint freezeTime;
        uint percent;
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
        require(stakeToken_ != address(0), "MRCHStaking::constructor: stake token address is 0x0");
        stakeToken = stakeToken_;

        require(rewardToken_ != address(0), "MRCHStaking::constructor: reward token address is 0x0");
        rewardToken = rewardToken_;
    }

    function addPool(uint rewardAmount_, uint startTime_, uint endTime_, uint freezeTime_, uint percent_) public onlyOwner {
        require(getTimeStamp() <= startTime_, "MRCHStaking::addPool: bad timing for the request");
        require(startTime_ < endTime_, "MRCHStaking::addPool: endTime > startTime");

        doTransferIn(msg.sender, rewardToken, rewardAmount_);

        pools.push(
            Pool({
                rewardAmount: rewardAmount_,
                startTime: startTime_,
                endTime: endTime_,
                total: 0,
                freezeTime: freezeTime_,
                percent: percent_ // scaled by 1e18, for example 5% = 5e18, 0.01% = 1e16
            })
        );
    }

    function stake(uint pid, uint amount) public returns (bool) {
        require(amount > 0, "MRCHStaking::stake: amount must be positive");

        uint timeStamp = getTimeStamp();
        require(timeStamp >= pools[pid].startTime, "MRCHStaking::stake: bad timing for the request");
        require(timeStamp < pools[pid].endTime, "MRCHStaking::stake: bad timing for the request");

        address staker = msg.sender;

        doTransferIn(staker, stakeToken, amount);

        // Transfer is completed
        uint part = (pools[pid].endTime.sub(timeStamp)).mul(amount);

        stakes[pid][staker].amount = stakes[pid][staker].amount.add(amount);
        stakes[pid][staker].startTime = getTimeStamp();
        stakes[pid][staker].fraction = stakes[pid][staker].fraction.add(part);

        pools[pid].total = pools[pid].total.add(part);

        emit Staked(pid, staker, amount);

        return true;
    }

    function withdraw(uint pid) public returns (bool) {
        require(claim(pid), "MRCHStaking::withdraw: claim error");

        uint amount = stakes[pid][msg.sender].amount;

        return withdrawWithoutReward(pid, amount);
    }

    function withdrawWithoutReward(uint pid, uint amount) public returns (bool) {
        return withdrawInternal(pid, msg.sender, amount);
    }

    function withdrawInternal(uint pid, address staker, uint amount) internal returns (bool) {
        require(amount > 0, "MRCHStaking::withdrawInternal: amount must be positive");
        require(amount <= stakes[pid][msg.sender].amount, "MRCHStaking::withdrawInternal: not enough balance");

        stakes[pid][staker].amount = stakes[pid][staker].amount.sub(amount);

        uint freezeTime = stakes[pid][staker].startTime.add(pools[pid].freezeTime);

        if (getTimeStamp() < freezeTime) {
            amount = amount.mul(pools[pid].percent).div(100).div(1e18);
        }

        doTransferOut(stakeToken, staker, amount);

        return true;
    }

    function claim(uint pid) public returns (bool) {
        require(getTimeStamp() > pools[pid].endTime, "MRCHStaking::claim: bad timing for the request");

        address staker = msg.sender;

        uint rewardAmount = totalReward(pid, staker);

        if (rewardAmount == 0) {
            return true;
        }

        doTransferOut(rewardToken, staker, rewardAmount);

        stakes[pid][staker].rewardOut = stakes[pid][staker].rewardOut.add(rewardAmount);

        emit RewardOut(pid, staker, rewardToken, rewardAmount);

        return true;
    }

    function totalReward(uint pid, address staker) public view returns (uint) {
        uint totalRewardAmount = pools[pid].rewardAmount;
        uint total = pools[pid].total;

        uint fraction = stakes[pid][staker].fraction;
        uint rewardOut = stakes[pid][staker].rewardOut;

        uint rewardAmount = totalRewardAmount.mul(fraction).div(total);

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
