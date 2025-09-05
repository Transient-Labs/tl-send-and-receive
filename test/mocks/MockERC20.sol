// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin-contracts-5.0.2/token/ERC20/ERC20.sol";

/// @title MockERC20
/// @notice Simple ERC20 for testing. Mints 10,000,000 tokens to `mintTo` in the constructor.
contract MockERC20 is ERC20 {
    constructor(address mintTo) ERC20("MockToken", "MOCK") {
        _mint(mintTo, 1000 ether);
    }
}
