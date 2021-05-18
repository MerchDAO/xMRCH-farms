// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./tokens/TokenMRCH.sol";
import "./tokens/TokenXMRCH.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/ReentrancyGuard.sol";

contract Staking is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Stake {
        uint256 amount;
        uint256 rewardAllowed;
        uint256 rewardDebt;
        uint256 distributed;
        uint256 lastAmount;
        uint256 stakeTime;
    }

    mapping(address => Stake) public stakes;

    // ERC20 LP MRCH token staking to the contract
    // and XMRCH token earned by stakers as reward.
    ERC20 public stakeToken;
    TokenXMRCH public rewardToken;

    uint256 public tokensPerStake;
    uint256 public producedReward;

    uint256 public startTime;
    uint256 public distributionTime;

    uint256 public allReward;
    uint256 public rewardTotal;
    uint256 public stakedTotal;
    uint256 public distributed;

    uint256 public allProduced;
    uint256 public producedTime;

    uint256 public halvingRound;
    uint256 public halvingTime;

    uint256 public epochRound;
    uint256 public epochTPS;

    uint256 public immutable maxCap;

    uint256 public fineTime;
    uint256 public finePercent;
    uint256 public finePrecision;
    uint256 public totalFine;

    event tokensStaked(uint256 amount, uint256 time, address indexed sender);
    event tokensClaimed(uint256 amount, uint256 time, address indexed sender);
    event tokensUnstaked(
        uint256 amount,
        uint256 fineAmount,
        uint256 time,
        address indexed sender
    );

    constructor(
        uint256 _rewardTotal, // Reward amount of tokens produced during `distributionTime`
        uint256 _stakingStart, // Time of staking start
        uint256 _distributionTime, // Time to produce `rewardTotal`
        uint256 _halvingTime, // Period of halving
        uint256 _fineTime,
        uint256 _finePercent,
        uint256 _finePrecision
    ) public {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        // Sets `DEFAULT_ADMIN_ROLE` as ``ADMIN_ROLE``'s admin role.
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

        require(_rewardTotal > 0, "Staking: amount of reward must be positive");
        rewardTotal = _rewardTotal;

        startTime = _stakingStart;
        producedTime = _stakingStart;
        distributionTime = _distributionTime;
        epochRound = 0;
        epochTPS = 0;
        halvingRound = 0;
        halvingTime = _halvingTime;
        maxCap = 0;
        fineTime = _fineTime;
        finePercent = _finePercent;
        finePrecision = _finePrecision;
    }

    /**
     * @dev Initializes the LP MRCH and XMRCH tokens
     *
     * Requirements:
     *
     * - `_IUniswapV2Pair` address of LP MRCH token.
     * - `_TokenXMRCH` address of DLS token.
     */
    function initialize(address _IUniswapV2Pair, address _TokenXMRCH) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        require(
            address(stakeToken) == address(0) &&
                address(rewardToken) == address(0),
            "Staking: contract already initialized"
        );
        stakeToken = ERC20(_IUniswapV2Pair);
        rewardToken = TokenXMRCH(_TokenXMRCH);
    }

    /**
     * @dev Runs new epoch every 7 days and executes the halving
     *      of Reward amount every 91 day
     *
     */
    function newEpoch(uint256 _tokensPerStake) private {
        epochTPS = _tokensPerStake;
        epochRound = block.timestamp.sub(startTime).div(distributionTime);

        if ((block.timestamp.sub(startTime).div(halvingTime)) > halvingRound) {
            allProduced = produced();
            producedTime = block.timestamp;
            rewardTotal = rewardTotal.div(2);
            halvingRound = block.timestamp.sub(startTime).div(halvingTime);
        }
    }

    /**
     * @dev Calculates the produced amount of reward tokens
     *
     */
    function produced() public view returns (uint256) {
        return
            allProduced.add(
                rewardTotal.mul(block.timestamp - producedTime).div(
                    distributionTime
                )
            );
    }

    /**
     * @dev Calculates and updates `tokensPerStake`
     *
     */
    function update() public {
        uint256 producedAtNow = produced();
        if (producedAtNow > producedReward && stakedTotal > 0) {
            uint256 producedNew = producedAtNow.sub(producedReward);
            tokensPerStake = tokensPerStake.add(
                producedNew.mul(1e18).div(stakedTotal)
            );
            producedReward = producedReward.add(producedNew);
        }

        if (block.timestamp.sub(startTime).div(distributionTime) > epochRound) {
            newEpoch(tokensPerStake);
        }
    }

    /**
     * @dev getRewardToken - return address of the reward token
     */
    function getRewardToken() external view returns (address) {
        return address(rewardToken);
    }

    /**
     * @dev getStakingToken - return address of the staking token
     */
    function getStakingToken() external view returns (address) {
        return address(stakeToken);
    }

    function getDecimals() external view returns (uint256, uint256) {
        return (ERC20(stakeToken).decimals(), ERC20(rewardToken).decimals());
    }

    /**
     * @dev `getUserInfoByAddress` - show information about `_user`
     */
    function getUserInfoByAddress(address _user)
        external
        view
        returns (
            uint256 staked_,
            uint256 available_,
            uint256 claimed_
        )
    {
        Stake storage staker = stakes[_user];
        staked_ = staker.amount;
        available_ = getClaim(_user);
        claimed_ = staker.distributed;

        return (staked_, available_, claimed_);
    }

    /**
     * @dev Stakes the LP MRCH tokens
     *
     * Requirements:
     *
     * - `_amount` in LP MRCH.
     */
    function stake(uint256 _amount) external returns (bool) {
        require(
            block.timestamp >= startTime,
            "Staking: staking time has not come yet"
        );

        require(_amount > 0, "Staking: amount must be positive");

        Stake storage staker = stakes[msg.sender];

        if (stakedTotal != 0) {
            update();
        } else if (
            block.timestamp.sub(startTime).div(distributionTime) > epochRound
        ) {
            newEpoch(tokensPerStake);
        }

        // Transfer specified amount of staking tokens to the contract
        IERC20(stakeToken).safeTransferFrom(msg.sender, address(this), _amount);

        stakedTotal = stakedTotal.add(_amount);
        staker.amount = staker.amount.add(_amount);
        staker.rewardDebt = staker.rewardDebt.add(
            _amount.mul(epochTPS).div(1e18)
        );

        staker.lastAmount = _amount;
        staker.stakeTime = block.timestamp;

        update();

        emit tokensStaked(_amount, block.timestamp, msg.sender);

        return true;
    }

    /**
     * @dev Unstakes the staked LP MRCH tokens
     *
     * Requirements:
     *
     * - `_amount` in LP MRCH.
     */
    function unstake(uint256 _amount)
        public
        payable
        nonReentrant
        returns (bool)
    {
        Stake storage staker = stakes[msg.sender];
        require(
            staker.amount >= _amount,
            "Staking: not enough tokens to unstake"
        );
        update();

        staker.rewardAllowed = staker.rewardAllowed.add(
            _amount.div(1e18).mul(epochTPS)
        );
        staker.amount = staker.amount.sub(_amount);

        uint256 unstakeAmount;
        uint256 fineAmount;
        if (block.timestamp - staker.stakeTime < fineTime) {
            if (staker.lastAmount <= _amount) {
                fineAmount = finePercent.mul(staker.lastAmount).div(
                    finePrecision
                );
                staker.lastAmount = 0;
                staker.stakeTime = 0;
            } else {
                fineAmount = finePercent.mul(_amount).div(finePrecision);
                staker.lastAmount = staker.lastAmount.sub(_amount);
            }
            unstakeAmount = _amount.sub(fineAmount);
            totalFine = totalFine.add(fineAmount);
        } else {
            unstakeAmount = _amount;
        }

        IERC20(stakeToken).safeTransfer(msg.sender, unstakeAmount);
        stakedTotal = stakedTotal.sub(_amount);

        emit tokensUnstaked(unstakeAmount, fineAmount, block.timestamp, msg.sender);

        return true;
    }

    /**
     * @dev Calculates available reward TokenXMRCH tokens
     *
     */
    function calcReward(
        address _staker,
        uint256 _tps,
        uint256 _epochRound
    ) private view returns (uint256 reward) {
        Stake storage staker = stakes[_staker];

        if (_epochRound == 0) return 0;

        reward = staker
            .amount
            .mul(_tps)
            .div(1e18)
            .add(staker.rewardAllowed)
            .sub(staker.rewardDebt)
            .sub(staker.distributed);
        return reward;
    }

    /**
     * @dev Claimes reward TokenXMRCH tokens
     *
     */
    function claim() public nonReentrant {
        update();

        uint256 reward = calcReward(msg.sender, epochTPS, epochRound);
        require(reward > 0, "Staking: nothing to claim");

        Stake storage staker = stakes[msg.sender];

        staker.distributed = staker.distributed.add(reward);
        distributed = distributed.add(reward);

        IERC20(rewardToken).safeTransfer(msg.sender, reward);

        emit tokensClaimed(reward, block.timestamp, msg.sender);
    }

    /**
     * @dev Shows amount of the reward TokenXMRCH
     *
     */
    function getClaim(address _staker) public view returns (uint256 reward) {
        uint256 _tps = tokensPerStake;
        uint256 _epochRound = epochRound;
        uint256 _epochTPS = epochTPS;

        if (stakedTotal > 0) {
            uint256 producedAtNow = produced();
            if (producedAtNow > producedReward) {
                uint256 producedNew = producedAtNow.sub(producedReward);
                _tps = _tps.add(producedNew.mul(1e18).div(stakedTotal));
            }
        }

        reward = calcReward(_staker, _epochTPS, _epochRound);

        return reward;
    }
}
