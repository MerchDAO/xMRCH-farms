// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";

contract EmuTokenLP is ERC20, ERC20Burnable {

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
}
