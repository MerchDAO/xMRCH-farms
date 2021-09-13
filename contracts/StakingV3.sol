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
    }

    mapping(address => Stake[]) public stakes;

    // MRCH token staking to the contract
    // and xMRCH token earned by stakers as reward.
    address public stakeToken;
    address public rewardToken;

    uint public epochPeriod;
    uint public epochReward;
    uint public halvingPeriod;

    uint public feePercent;
    uint public feeTime;

    event tokensStaked();
    event tokensClaimed();
    event tokensUnstaked();

    constructor(
        address MRCH,
        address xMRCH,
        uint epochPeriod_,
        uint epochReward_,
        uint halvingPeriod_,
        uint feePercent_,
        uint feeTime_
    ) {
        stakeToken = MRCH;
        rewardToken = xMRCH;

        epochPeriod = epochPeriod_;
        epochReward = epochReward_;
        halvingPeriod = halvingPeriod_;

        feePercent = feePercent_;
        feeTime = feeTime_;
    }

    /**
     * @dev `getStakeInfo` - show information about user stake
     * @param user The user address
     * @param stakeId The id of user stake
     * @return (amount, stakeTime, status) The staked MRCH amount, stake time and stake status
     */
    function getStakeInfo(address user, uint stakeId) external view returns (uint, uint, bool) {
        Stake memory userStake = stakes[user][stakeId];

        uint amount = userStake.amountIn;
        uint stakeTime = userStake.stakeTime;
        bool status = userStake.status;

        return (amount, stakeTime, status);
    }

    /**
     * @dev Stakes the MRCH tokens
     * @param amount The MRCH amount
     * @return The result (true or false)
     */
    function stake(uint amount) external nonReentrant returns (bool) {
        Stake memory userStake;

        userStake.amountIn = doTransferIn(msg.sender, address(this), amount);
        userStake.stakeTime = block.timestamp;
        userStake.status = true;

        stakes[msg.sender].push(userStake);

        return true;
    }

    /**
     * @dev Unstakes the staked MRCH tokens
     * @param stakeId The stake id of user stake
     * @return The result (true or false)
     */
    function unstake(uint stakedId) public nonReentrant returns (bool) {
        claim(stakedId);
        //@todo fee

        stakes[msg.sender][stakedId].status = false;

        return true;
    }

    /**
     * @dev Calculates available reward xMRCH tokens
     * @param staker The staker address
     * @param stakeId The stake id of user stake
     * @return reward
     */
    function calcReward(address staker, uint stakeId) public view returns (uint) {
        uint reward;
        staker;

        return reward;
    }

    /**
     * @dev Claims reward xMRCH tokens
     * @param stakeId The stake id of user stake
     */
    function claim(uint stakeId) public nonReentrant {

    }

    /**
     * @dev Shows amount of the reward xMRCH
     * @param staker The staker address
     * @param stakeId The stake id of user stake
     * @return reward
     */
    function getClaim(address staker, uint stakeId) public view returns (uint) {
        uint reward;

        reward = calcReward(staker, stakeId);

        return reward;
    }

    function transferTokens(address token, address to, uint amount) public onlyOwner {
        doTransferOut(token, to, amount);
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
