// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "hardhat/console.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

contract MerchStaking is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint equivalentAmount;
        uint rewardOut;
    }

    // Info of each pool.
    struct Pool {
        uint stakingCap; // Pool staking tokens limit
        uint rewardAPY; // scaledBy 1e18
        uint startTime; 
        uint endTime; 
        uint stakedTotal; 
    }
    Pool[] public pools;

    mapping(uint => mapping(address => Stake)) public stakes;

    address public stakeToken; // Uniswap LP token from pool MRCH/USDT
    address public rewardToken; // MRCH token

    uint public constant blocksPerYear = 2102400;
    uint public rewardRatePerBlock;

    address public admin;

    event Staked(address staker, uint amount, uint equivalent);
    event RewardOut(address staker, address token, uint amount);

    constructor(
        address _stakeToken,
        address _rewardToken
    ) {
        admin = msg.sender;

        require(_stakeToken != address(0), "MerchStaking: stake token address is 0");
        stakeToken = _stakeToken;

        require(_rewardToken != address(0), "MerchStaking: reward token address is 0");
        rewardToken = _rewardToken;
    }
    
    function addPool(uint _stakingCap, uint _rewardAPY, uint _startTime, uint _endTime) public onlyOwner {
        pools.push(
            Pool({
            stakingCap: _stakingCap,
            rewardAPY: _rewardAPY,
            startTime: _startTime,
            endTime: _endTime,
            stakedTotal: 0
            })
        );
    }
    // function addReward(uint rewardAmount) public returns (bool) {
    //     require(rewardAmount > 0, "MerchStaking: reward must be positive");

    //     transferIn(msg.sender, rewardToken, rewardAmount);

    //     allReward = allReward.add(rewardAmount);

    //     return true;
    // }

    // function removeUnusedReward() public returns (bool) {
    //     require(getTimeStamp() > stakingEnd, "MerchStaking: bad timing for the request");
    //     require(msg.sender == admin, "MerchStaking: Only admin can remove unused reward");

    //     uint unusedReward = allReward.sub(calcReward(stakedTotal));
    //     allReward = allReward.sub(unusedReward);

    //     transferOut(rewardToken, admin, unusedReward);

    //     return true;
    // }

    function stake(uint _pid, uint _amount) public returns (bool) {
        require(_amount > 0, "MerchStaking: must be positive");
        require(getTimeStamp() >= pools[_pid].startTime, "MerchStaking: bad timing for the request");
        require(getTimeStamp() < pools[_pid].endTime, "MerchStaking: bad timing for the request");

        address staker = msg.sender;
        uint equivalent = calcRewardTokenEquivalent(_amount);

        if (equivalent > (pools[_pid].stakingCap.sub(pools[_pid].stakedTotal))) {
            uint newEquivalent = pools[_pid].stakingCap.sub(pools[_pid].stakedTotal);
            uint coefficient = newEquivalent.mul(1e18).div(equivalent);
            equivalent = newEquivalent;
            _amount = _amount.mul(coefficient).div(1e18);
        }

        require(equivalent > 0, "MerchStaking: Staking cap is filled");
        require(equivalent.add(pools[_pid].stakedTotal) <= pools[_pid].stakingCap, "MerchStaking: this will increase staking amount pass the cap");

        transferIn(staker, stakeToken, _amount);

        emit Staked(_pid, staker, _amount, equivalent);

        // Transfer is completed
        pools[_pid].stakedTotal = pools[_pid].stakedTotal.add(equivalent);
        stakes[_pid][staker].amount = stakes[_pid][staker].amount.add(_amount);
        stakes[_pid][staker].equivalentAmount = stakes[_pid][staker].equivalentAmount.add(equivalent);

        return true;
    }

    function withdraw(uint _pid) public returns (bool) {
        require(claimReward(), "MerchStaking: claim error");
        uint amount = stakes[_pid][msg.sender].amount;

        return withdrawWithoutReward(amount);
    }

    function withdrawWithoutReward(uint _amount) public returns (bool) {
        return withdrawInternal(msg.sender, _amount);
    }

    function withdrawInternal(uint _pid, address _staker, uint _amount) internal returns (bool) {
        // require(getTimeStamp() >= withdrawStart, "MerchStaking: bad timing for the request");
        require(amount > 0, "MerchStaking: must be positive");
        require(amount <= stakes[_pid][msg.sender].amount, "MerchStaking: not enough balance");

        stakes[_pid][_staker].amount = stakes[_pid][_staker].amount.sub(_amount);

        transferOut(stakeToken, _staker, _amount);

        return true;
    }

    function claimReward(uint _pid) public returns (bool) {
        require(getTimeStamp() > pools[_pid].endTime, "MerchStaking: bad timing for the request");

        address staker = msg.sender;

        uint rewardAmount = currentReward(_pid, staker);

        if (rewardAmount == 0) {
            return true;
        }

        transferOut(rewardToken, staker, rewardAmount);

        stakes[_pid][staker].rewardOut = stakes[_pid][staker].rewardOut.add(rewardAmount);

        emit RewardOut(staker, rewardToken, rewardAmount);

        return true;
    }

    function calcTotalReward(address _staker) public view returns (uint) {
        uint amount = stakes[_pid][_staker].equivalentAmount;

        return calcReward(amount);
    }

    function calcReward(uint _amount) public view returns (uint) {
        // uint duration = withdrawStart.sub(stakingEnd);

        // .div(15) - 1 eth block is mine every ~15 sec, rewardRatePerBlock scaled by 1e18, and 100 is %
        // uint rewardAmount = amount.mul(rewardRatePerBlock).mul(duration).div(15).div(1e18).div(100);
        return rewardAmount;
    }

    function currentReward(address staker) public view returns (uint) {
        // uint totalStakerReward = calcTotalReward(staker);
        // uint timeStamp = getTimeStamp();

        // if (totalStakerReward == 0 || timeStamp < stakingEnd) {
        //     return 0;
        // }

        // uint allTime = withdrawStart.sub(stakingEnd);

        // uint time = timeStamp < withdrawStart ? timeStamp.sub(stakingEnd) : allTime;

        // uint stakerRewardToTimestamp = totalStakerReward.mul(time).div(allTime); // 1 eth block is mine every ~15 sec
        // uint rewardOut = stakes[staker].rewardOut;

        // return stakerRewardToTimestamp.sub(rewardOut);
    }

    function calcRewardTokenEquivalent(uint _amount) public view returns (uint) {
        uint decimalsRewardToken = ERC20(rewardToken).decimals();
        uint decimalsStakeToken = ERC20(stakeToken).decimals();
        uint factor;

        if (decimalsStakeToken >= decimalsRewardToken) {
            factor = 10**(decimalsStakeToken - decimalsRewardToken);
        } else {
            factor = 10**(decimalsRewardToken - decimalsStakeToken);
        }

        address _token0 = IUniswapV2Pair(stakeToken).token0();
        address _token1 = IUniswapV2Pair(stakeToken).token1();

        uint balance = rewardToken == _token0 ? (IERC20(_token0).balanceOf(stakeToken)) : (IERC20(_token1).balanceOf(stakeToken));
        return _amount.mul(factor).mul(2).mul(balance).div(IERC20(stakeToken).totalSupply());
    }

    function transferOut(address _token, address _to, uint _amount) internal {
        if (_amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(_token);
        ERC20Interface.safeTransfer(_to, _amount);
    }

    function transferIn(address _from, address _token, uint _amount) internal {
        IERC20 ERC20Interface = IERC20(_token);
        ERC20Interface.safeTransferFrom(_from, address(this), _amount);
    }

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }
}