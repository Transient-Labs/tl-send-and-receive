// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC721} from "@openzeppelin-contracts-5.6.1/token/ERC721/ERC721.sol";

/// @title MockERC721
/// @notice Simple ERC721 for testing. Mints token ID 1 to `mintTo` in the constructor.
contract MockERC721 is ERC721 {
    constructor(address mintTo) ERC721("Mock721", "M721") {
        _safeMint(mintTo, 1);
    }
}
