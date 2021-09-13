// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-newone/access/Ownable.sol";
import "@openzeppelin/contracts-newone/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-newone/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-newone/security/ReentrancyGuard.sol";

contract StakingV3 is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
        uint stakeTime;
        bool status;
    }

    mapping(address => Stake[]) public stakes;

    // ERC20 LP MRCH token staking to the contract
    // and XMRCH token earned by stakers as reward.
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
        address IUniswapV2Pair_,
        address TokenXMRCH_,
        uint epochPeriod_,
        uint epochReward_,
        uint halvingPeriod_,
        uint feePercent_,
        uint feeTime_
    ) {
        stakeToken = IUniswapV2Pair_;
        rewardToken = TokenXMRCH_;

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
     * @return (amount, stakeTime, status) The staked LP MRCH amount, available claim amount and claimed amount
     */
    function getStakeInfo(address user, uint stakeId) external view returns (uint, uint, bool) {
        Stake memory userStake = stakes[user][stakeId];

        uint amount = userStake.amount;
        uint stakeTime = userStake.stakeTime;
        bool status = userStake.status;

        return (amount, stakeTime, status);
    }

    /**
     * @dev Stakes the LP MRCH tokens
     * @param amount The LP MRCH amount
     * @return The result (true or false)
     */
    function stake(uint amount) external returns (bool) {
        Stake memory userStake;

        userStake.amount = amount;
        userStake.stakeTime = block.timestamp;
        userStake.status = true;

        stakes[msg.sender].push(userStake);

        return true;
    }

    /**
     * @dev Unstakes the staked LP MRCH tokens
     * @param _amount The unstake amount
     * @return The result (true or false)
     */
    function unstake(uint _amount) public nonReentrant returns (bool) {
        _amount;

        return true;
    }

    /**
     * @dev Calculates available reward TokenXMRCH tokens
     * @param _staker The staker address
     * @return reward
     */
    function calcReward(address _staker) private view returns (uint) {
        uint reward;
        _staker;

        return reward;
    }

    /**
     * @dev Claims reward TokenXMRCH tokens
     */
    function claim() public nonReentrant {

    }

    /**
     * @dev Shows amount of the reward TokenXMRCH
     * @param _staker The staker address
     * @return reward
     */
    function getClaim(address _staker) public view returns (uint) {
        uint reward;

        reward = calcReward(_staker);

        return reward;
    }

    function transferTokens(address token, address to, uint amount) public onlyOwner {
        doTransferOut(token, to, amount);
    }

    function doTransferOut(address token, address to, uint amount) internal {
        if (amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransfer(to, amount);
    }
}
