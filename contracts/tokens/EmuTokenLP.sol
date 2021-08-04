// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";

contract EmuTokenLP is ERC20, ERC20Burnable {
    uint112 public reserve0;
    uint112 public reserve1;
    uint32 public blockTimeStampLast;

    address public token0;
    address public token1;

    constructor(
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mints the LP tokens to the caller.
     *
     * Requirements:
     *
     * - `_amount` in LP.
     */
    function Mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimeStampLast);
    }

    function setBlockTimeStampLast(uint32 blockTimeStampLast_) public {
        blockTimeStampLast = blockTimeStampLast_;
    }

    function setData(address tokenA, address tokenB, uint112 reserveA, uint112 reserveB) public {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (reserve0, reserve1) = tokenA < tokenB ? (reserveA, reserveB) : (reserveB, reserveA);
    }
}
