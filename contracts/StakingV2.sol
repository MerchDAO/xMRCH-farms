// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";

contract StakingV2 is AccessControl {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice A checkpoint for marking number of stake tokens from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 amount;
    }

    /// @notice A record of stake tokens checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    mapping (address => uint32) public lastClaim; // block number of last claim for staker

    address public stakeToken; // Uniswap LP token from pool MRCH|ETH
    address public rewardToken; // MRCH token

    uint public startBlockNum; // start block num
    uint public roundBlocks; // every round time in blocks, new reward amount
    uint public roundRewardAmount; // reward for each round

    event RewardOut(address staker, uint amount);
    event StakeAmountChanged(address staker, uint oldAmount, uint newAmount);

    constructor(
        address stakeToken_,
        address rewardToken_,
        uint startBlockNum_,
        uint roundBlocks_,
        uint roundRewardAmount_
    ) {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        // Sets `DEFAULT_ADMIN_ROLE` as ``ADMIN_ROLE``'s admin role.
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

        require(stakeToken_ != address(0), "MRCHStaking: stake token address is 0");
        stakeToken = stakeToken_;

        require(rewardToken_ != address(0), "MRCHStaking: reward token address is 0");
        rewardToken = rewardToken_;

        startBlockNum = startBlockNum_;

        roundBlocks = roundBlocks_;

        require(roundRewardAmount > 0, "MRCHStaking: reward amount address is 0");
        roundRewardAmount = roundRewardAmount_;
    }

    function addReward(uint amount) public returns (bool) {
        require(amount > 0, "MRCHStaking::addReward: reward must be positive");

        doTransferIn(msg.sender, rewardToken, amount);

        return true;
    }

    function stake(uint amountIn) public returns (bool) {
        require(amountIn > 0, "MRCHStaking::stake: amount must be positive");
        require(block.number >= startBlockNum.sub(roundBlocks), "MRCHStaking::stake: bad timing for the request");

        address staker = msg.sender;

        doTransferIn(staker, stakeToken, amountIn);

        uint32 stakerNum = numCheckpoints[staker];
        uint96 stakerOldAmount = stakerNum > 0 ? checkpoints[staker][stakerNum - 1].amount : 0;
        uint96 stakerNewAmount = add96(stakerOldAmount, uint96(amountIn), "MRCHStaking::stake: staker tokens amount overflows");
        _writeCheckpoint(staker, stakerNum, stakerOldAmount, stakerNewAmount);

        uint32 contractNum = numCheckpoints[address(this)];
        uint96 totalOldAmount = stakerNum > 0 ? checkpoints[address(this)][contractNum - 1].amount : 0;
        uint96 totalNewAmount = add96(totalOldAmount, uint96(amountIn), "MRCHStaking::stake: contract tokens amount overflows");
        _writeCheckpoint(address(this), contractNum, totalOldAmount, totalNewAmount);

        return true;
    }

    function withdraw() public returns (bool) {
        require(claimReward(), "MRCHStaking::withdraw: claim error");

        uint amount = getPriorAmount(msg.sender, block.number);
        return withdrawWithoutReward(amount);
    }

    function withdrawWithoutReward(uint amount) public returns (bool) {
        return withdrawInternal(msg.sender, amount);
    }

    function withdrawInternal(address staker, uint amountOut) internal returns (bool) {
        require(block.number > startBlockNum, "MRCHStaking::withdrawInternal: bad timing for the request");
        require(amountOut > 0, "MRCHStaking::withdrawInternal: must be positive");

        uint32 stakerNum = numCheckpoints[staker];
        uint96 stakerOldAmount = stakerNum > 0 ? checkpoints[staker][stakerNum - 1].amount : 0;
        uint96 stakerNewAmount = sub96(stakerOldAmount, uint96(amountOut), "MRCHStaking::withdrawInternal: staker token amount underflows");
        _writeCheckpoint(staker, stakerNum, stakerOldAmount, stakerNewAmount);

        uint32 contractNum = numCheckpoints[address(this)];
        uint96 totalOldAmount = stakerNum > 0 ? checkpoints[address(this)][contractNum - 1].amount : 0;
        uint96 totalNewAmount = sub96(totalOldAmount, uint96(amountOut), "MRCHStaking::withdrawInternal: contract tokens amount underflows");
        _writeCheckpoint(address(this), contractNum, totalOldAmount, totalNewAmount);

        doTransferOut(stakeToken, staker, amountOut);

        return true;
    }

    function claimReward() public returns (bool) {
        address staker = msg.sender;

        uint rewardAmount = calcReward(staker);

        if (rewardAmount == 0) {
            return true;
        }

        doTransferOut(rewardToken, staker, rewardAmount);

        lastClaim[staker] = uint32(currentRoundNum());

        emit RewardOut(staker, rewardAmount);

        return true;
    }

    function calcReward(address staker) public view returns (uint) {
        uint reward;
        uint lastRound = lastClaim[staker];

        uint stakerAmount;
        uint totalAmount;
        uint endBlockRoundNum;

        for(uint i = lastRound; i < currentRoundNum(); i++) {
            endBlockRoundNum = startBlockNum.add(roundBlocks * i);
            stakerAmount = getPriorAmount(staker, endBlockRoundNum);
            totalAmount = getPriorAmount(address(this), endBlockRoundNum);

            reward = reward.add(roundRewardAmount.mul(stakerAmount).div(totalAmount));
        }

        return reward;
    }

    function currentRoundNum() public view returns (uint) {
        return roundNum(block.number);
    }

    function roundNum(uint blockNum) public view returns (uint) {
        if (blockNum > startBlockNum) {
            return blockNum.sub(startBlockNum).div(roundBlocks) + 1; // first round num is 1
        } else {
            return 0;
        }
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

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }

    /**
     * @notice Determine the prior number of stake tokens for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of stake tokens the account had as of the given block
     */
    function getPriorAmount(address account, uint blockNumber) public view returns (uint96) {
        require(blockNumber < block.number, "MRCHStaking::getPriorAmount: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].amount;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.amount;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].amount;
    }

    function _writeCheckpoint(address user, uint32 nCheckpoints, uint96 oldAmount, uint96 newAmount) internal {
        uint32 blockNumber = safe32(block.number, "MRCHStaking::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[user][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[user][nCheckpoints - 1].amount = newAmount;
        } else {
            checkpoints[user][nCheckpoints] = Checkpoint(blockNumber, newAmount);
            numCheckpoints[user] = nCheckpoints + 1;
        }

        emit StakeAmountChanged(user, oldAmount, newAmount);
    }

    function add96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        uint96 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub96(uint96 a, uint96 b, string memory errorMessage) internal pure returns (uint96) {
        require(b <= a, errorMessage);
        return a - b;
    }

    function safe32(uint n, string memory errorMessage) pure internal returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }
}
