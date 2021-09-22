// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-newone/access/Ownable.sol";
import "@openzeppelin/contracts-newone/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-newone/security/ReentrancyGuard.sol";

contract StakingV3 is Ownable, ReentrancyGuard {

    struct Stake {
        uint amountIn;
        uint stakeTime;
        bool status;
        uint rewardOut;
    }

    mapping(address => Stake[]) public stakes;

    uint public totalStakeAmount;

    // halving => epoch => amount
    mapping(uint => mapping(uint => uint)) public totalAmountEpoch;

    // MRCH token staking to the contract
    // and xMRCH token earned by stakers as reward.
    address public stakeToken;
    address public rewardToken;

    uint public startTime;
    uint public epochPeriod;
    uint public stakeTimeToEpoch;
    uint public startEpochReward;
    uint public halvingPeriod;

    uint public feePercent;
    uint public feeTime;

    event Staked(address user, uint amount, uint timestamp);
    event Claimed(address user, uint stakeId);
    event Unstaked(address user, uint stakerId);

    constructor(
        address MRCH,
        address xMRCH,
        uint startTime_,
        uint epochPeriod_,
        uint stakeTimeToEpoch_,
        uint startEpochReward_,
        uint halvingPeriod_,
        uint feePercent_,
        uint feeTime_
    ) {
        stakeToken = MRCH;
        rewardToken = xMRCH;

        require(startTime > block.timestamp, "StakingV3::constructor: Bad start time");

        startTime = startTime_;
        epochPeriod = epochPeriod_;
        stakeTimeToEpoch = stakeTimeToEpoch_;
        startEpochReward = startEpochReward_;
        halvingPeriod = halvingPeriod_;

        feePercent = feePercent_;
        feeTime = feeTime_;
    }

    /**
     * @dev `getStakeInfo` - show information about user stake
     * @param staker The user address
     * @param stakeId The id of user stake
     * @return (amount, stakeTime, status, rewardOut) The staked MRCH amount, stake time, stake status and claimed reward
     */
    function getStakeInfo(address staker, uint stakeId) public view returns (uint, uint, bool, uint) {
        Stake memory userStake = stakes[staker][stakeId];

        uint amount = userStake.amountIn;
        uint stakeTime = userStake.stakeTime;
        bool status = userStake.status;
        uint rewardOut = userStake.rewardOut;

        return (amount, stakeTime, status, rewardOut);
    }

    /**
     * @dev Stakes the MRCH tokens
     * @param amount The MRCH amount
     * @return The result (true or false)
     */
    function stake(uint amount) external nonReentrant returns (bool) {
        Stake memory userStake;

        address account = msg.sender;
        uint amountIn = doTransferIn(account, address(this), amount);
        uint timestamp = block.timestamp;

        userStake.amountIn = amountIn;
        userStake.stakeTime = timestamp;
        userStake.status = true;

        stakes[account].push(userStake);

        totalStakeAmount += amountIn;

        uint epochNum = getCurrentEpoch();
        uint halvingNum = getCurrentHalving();

        totalAmountEpoch[halvingNum][epochNum] += amountIn;

        emit Staked(account, amountIn, timestamp);

        return true;
    }

    /**
     * @dev Unstakes the staked MRCH tokens
     * @param stakeId The stake id of user stake
     * @return The result (true or false)
     */
    function unstake(uint stakeId) public nonReentrant returns (bool) {
        claim(stakeId);

        return unstakeWithoutClaim(stakeId);
    }

    function unstakeWithoutClaim(uint stakeId) public returns (bool) {
        address account = msg.sender;

        uint amountOut = stakes[account][stakeId].amountIn;
        stakes[account][stakeId].status = false;

        totalStakeAmount -= amountOut;

        if (getFee(getCurrentTimestamp())) {
            uint feeAmount = feePercent * amountOut / 1e18;

            doTransferOut(stakeToken, account, amountOut - feeAmount);
            doTransferOut(stakeToken, owner(), feeAmount);
        } else {
            doTransferOut(stakeToken, account, amountOut);
        }

        emit Unstaked(account, stakeId);

        return true;
    }

    function getFee(uint timestamp) public view returns (bool) {
        if ((timestamp - startTime) / epochPeriod < feeTime) {
            return false;
        } else {
            return true;
        }
    }

    /**
     * @dev Calculates available reward xMRCH tokens
     * @param staker The staker address
     * @param stakeId The stake id of user stake
     * @return reward
     */
    function calcReward(address staker, uint stakeId) public view returns (uint) {
        uint totalReward;
        uint currentEpoch = getCurrentEpoch();
        uint currentHalving = getCurrentHalving();

        (uint amount, uint stakeTime, bool status, uint rewardOut) = getStakeInfo(staker, stakeId);

        if (status == false) {
            return 0;
        }

        uint startEpochNum = getEpochNum(stakeTime);
        uint startHalvingNum = getHalvingNum(stakeTime);

        for(uint halvingNum = startHalvingNum; halvingNum < currentHalving; halvingNum++) {
            uint epochReward = getEpochReward(halvingNum);

            for(uint epochNum = startEpochNum; epochNum < currentEpoch; epochNum++) {
                totalReward += amount * epochReward / totalAmountEpoch[halvingNum][epochNum];
            }
        }

        if (totalReward > rewardOut) {
            return totalReward - rewardOut;
        } else {
            return 0;
        }
    }

    /**
     * @dev Claims reward xMRCH tokens
     * @param stakeId The stake id of user stake
     */
    function claim(uint stakeId) public nonReentrant {
        uint amount = calcReward(msg.sender, stakeId);

        if (amount == 0) {
            return;
        }

        stakes[msg.sender][stakeId].rewardOut += amount;

        doTransferOut(rewardToken, msg.sender, amount);
    }

    function getEpochReward(uint halvingNum) public view returns (uint) {
        return startEpochReward / (2 ** halvingNum);
    }

    function getCurrentEpochReward() public view returns (uint) {
        uint currentHalving = getCurrentHalving();

        return getEpochReward(currentHalving);
    }

    function getCurrentEpoch() public view returns (uint) {
        uint currentTimestamp = getCurrentTimestamp();

        return getEpochNum(currentTimestamp);
    }

    function getEpochNum(uint timestamp) public view returns (uint) {
        if (timestamp < startTime + epochPeriod) {
            return 0;
        } else {
            return (timestamp - startTime) / epochPeriod;
        }
    }

    function getHalvingNum(uint timestamp) public view returns (uint) {
        if (timestamp < startTime + halvingPeriod) {
            return 0;
        } else {
            return (timestamp - startTime) / halvingPeriod;
        }
    }

    function getCurrentHalving() public view returns (uint) {
        uint currentTimestamp = getCurrentTimestamp();

        return getHalvingNum(currentTimestamp);
    }

    /**
     * @dev Shows amount of the reward xMRCH
     * @param staker The staker address
     * @param stakeId The stake id of user stake
     * @return reward
     */
    function getClaim(address staker, uint stakeId) public view returns (uint) {
        return calcReward(staker, stakeId);
    }

    function transferTokens(address token, address to, uint amount) public onlyOwner {
        doTransferOut(token, to, amount);
    }

    function getCurrentTimestamp() public view returns (uint) {
        return block.timestamp;
    }

    function doTransferIn(address from, address token, uint amount) internal returns (uint) {
        uint balanceBefore = ERC20(token).balanceOf(address(this));
        ERC20(token).transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
            case 0 {                       // This is a non-standard ERC-20
                success := not(0)          // set success to true
            }
            case 32 {                      // This is a compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0)        // Set `success = returndata` of external call
            }
            default {                      // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "TOKEN_TRANSFER_IN_FAILED");

        // Calculate the amount that was *actually* transferred
        uint balanceAfter = ERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;   // underflow already checked above, just subtract
    }

    function doTransferOut(address token, address to, uint amount) internal {
        ERC20(token).transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
            case 0 {                      // This is a non-standard ERC-20
                success := not(0)          // set success to true
            }
            case 32 {                     // This is a complaint ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0)        // Set `success = returndata` of external call
            }
            default {                     // This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "TOKEN_TRANSFER_OUT_FAILED");
    }
}
