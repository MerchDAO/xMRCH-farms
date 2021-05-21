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
        address user;
        uint256 amount;
        uint64 sinceBlock;
        uint64 untilBlock;
    }

    mapping(address => Stake) public stakes;

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

        // @Todo add data of stake

        return true;
    }

    function withdraw() public returns (bool) {
        require(claimReward(), "MRCHStaking::withdraw: claim error");

        uint amount = 0; // @Todo get all stake amount

        return withdrawWithoutReward(amount);
    }

    function withdrawWithoutReward(uint amount) public returns (bool) {
        return withdrawInternal(msg.sender, amount);
    }

    function withdrawInternal(address staker, uint amountOut) internal returns (bool) {
        require(block.number > startBlockNum, "MRCHStaking::withdrawInternal: bad timing for the request");
        require(amountOut > 0, "MRCHStaking::withdrawInternal: must be positive");

        // @Todo change data of stake

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

        emit RewardOut(staker, rewardAmount);

        return true;
    }

    function calcReward(address staker) public view returns (uint) {
        uint reward;

        // @Todo calc reward

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
