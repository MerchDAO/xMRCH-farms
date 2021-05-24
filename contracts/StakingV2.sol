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

    struct Stake {
        uint256 amount;
        uint64 sinceBlock;
    }

    struct Total {
        uint256 amount;
    }

    // round => user => stake
    mapping(address => Stake) public stakes;
    Total public total;

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
        require(block.number < startBlockNum.add(roundBlocks), "MRCHStaking::stake: bad timing for the request");

        address user = msg.sender;

        doTransferIn(user, stakeToken, amountIn);

        Stake storage staker = stakes[user];
        staker.amount = amountIn;

        total.amount = total.amount.add(amountIn);

        return true;
    }

    function withdraw() public returns (bool) {
        require(claimReward(), "MRCHStaking::withdraw: claim error");

        uint amount = stakes[msg.sender].amount;

        return withdrawWithoutReward(amount);
    }

    function withdrawWithoutReward(uint amount) public returns (bool) {
        return withdrawInternal(msg.sender, amount);
    }

    function withdrawInternal(address user, uint amountOut) internal returns (bool) {
        require(block.number > startBlockNum, "MRCHStaking::withdrawInternal: bad timing for the request");
        require(amountOut > 0, "MRCHStaking::withdrawInternal: must be positive");

        Stake storage staker = stakes[user];
        staker.amount = staker.amount.sub(amountOut);

        total.amount = total.amount.sub(amountOut);

        doTransferOut(stakeToken, user, amountOut);

        return true;
    }

    function claimReward() public returns (bool) {
        require(block.number >= startBlockNum.add(roundBlocks), "MRCHStaking::stake: bad timing for the request");

        address staker = msg.sender;

        uint rewardAmount = calcReward(staker);

        if (rewardAmount == 0) {
            return true;
        }

        doTransferOut(rewardToken, staker, rewardAmount);

        emit RewardOut(staker, rewardAmount);

        return true;
    }

    function calcReward(address user) public view returns (uint) {
        uint reward = roundRewardAmount.mul(stakes[user].amount).div(total.amount);

        return reward;
    }

    function getRoundNum() public view returns (uint) {
        return roundNum(block.number);
    }

    function roundNum(uint blockNum) public view returns (uint) {

    }

    function doTransferOut(address token, address to, uint amount) internal {
        if (amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransfer(to, amount);
    }

    function doTransferIn(address from, address token, uint amount) internal {
        if (amount == 0) {
            return;
        }

        IERC20 ERC20Interface = IERC20(token);
        ERC20Interface.safeTransferFrom(from, address(this), amount);
    }

    function getTimeStamp() public view virtual returns (uint) {
        return block.timestamp;
    }
}
