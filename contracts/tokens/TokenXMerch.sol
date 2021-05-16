// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";

contract TokenXMRCH is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        uint256 initialSupply,
        string memory name,
        string memory symbol
    ) public ERC20(name, symbol) {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Sets DEFAULT_ADMIN_ROLE as ``ADMIN_ROLE``'s admin role.
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

        // Sets ADMIN_ROLE as ``MINTER_ROLE``'s admin role.
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);

        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Mints the DLS tokens to the caller.
     *
     * Requirements:
     *
     * - `_amount` in DLS.
     * - caller must have a `MINTER_ROLE`
     */
    function Mint(uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller has not proves");
        _mint(msg.sender, amount);
    }
}
