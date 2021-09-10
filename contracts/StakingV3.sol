// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./tokens/TokenMRCH.sol";
import "./tokens/XMRCHToken.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

contract StakingV3 is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Stake {
        uint amount;
    }

    mapping(address => Stake) public stakes;

    // ERC20 LP MRCH token staking to the contract
    // and XMRCH token earned by stakers as reward.
    address public stakeToken;
    address public rewardToken;

    event tokensStaked();
    event tokensClaimed();
    event tokensUnstaked();

    constructor(
        address _IUniswapV2Pair,
        address _TokenXMRCH
    ) {
        stakeToken = _IUniswapV2Pair;
        rewardToken = _TokenXMRCH;
    }

    /**
     * @dev `getUserInfoByAddress` - show information about `_user`
     * @param _user The user address
     * @return (staked, available, claimed) The staked LP MRCH amount, available claim amount and claimed amount
     */
    function getUserInfoByAddress(address _user) external view returns (uint256, uint256, uint256) {
        Stake memory staker = stakes[_user];

        uint staked_ = staker.amount;
        uint available_ = 0;
        uint claimed_ = 0;

        return (staked_, available_, claimed_);
    }

    /**
     * @dev Stakes the LP MRCH tokens
     * @param _amount The LP MRCH amount
     * @return The result (true or false)
     */
    function stake(uint256 _amount) external returns (bool) {
        _amount;

        return true;
    }

    /**
     * @dev Unstakes the staked LP MRCH tokens
     * @param _amount The unstake amount
     * @return The result (true or false)
     */
    function unstake(uint256 _amount) public nonReentrant returns (bool) {
        _amount;

        return true;
    }

    /**
     * @dev Calculates available reward TokenXMRCH tokens
     * @param _staker The staker address
     * @return reward
     */
    function calcReward(address _staker) private view returns (uint256) {
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
    function getClaim(address _staker) public view returns (uint256) {
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
