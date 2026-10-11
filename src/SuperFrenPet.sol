// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Super Fren Pet
/// @notice A fixed supply of one billion SFP, with 18 decimals and ordinary ERC-20 transfers.
/// @dev The immediate deployer receives the entire supply. When deployed through a factory,
///      the factory receives it. There are no external mint, burn, or administrative functions.
contract SuperFrenPet is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("Super Fren Pet", "SFP") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
