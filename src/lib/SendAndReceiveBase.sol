// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5.0.2/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts-5.0.2/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin-contracts-5.0.2/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin-contracts-5.0.2/utils/Address.sol";
import {
    ERC165Upgradeable,
    IERC165
} from "@openzeppelin-contracts-upgradeable-5.0.2/utils/introspection/ERC165Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin-contracts-upgradeable-5.0.2/utils/ReentrancyGuardUpgradeable.sol";
import {IERC1155Receiver} from "@openzeppelin-contracts-5.0.2/token/ERC1155/IERC1155Receiver.sol";

/// @title Send and Receive Base
/// @notice A base abstract contract that receives 1155 tokens and does something with them
/// @author Transient Labs, Inc.
/// @custom:version 2.0.0

abstract contract SendAndReceiveBase is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC165Upgradeable,
    IERC1155Receiver
{
    ////////////////////////////////////////////////////////////////////////////
    // Types
    ////////////////////////////////////////////////////////////////////////////

    using SafeERC20 for IERC20;
    using Address for address payable;

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////

    event Redeemed(address indexed recipient, uint256 indexed amount);
    event RedemptionClosed();

    ////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////

    error FromZeroAddress();
    error ArrayLengthMismatch();
    error ZeroAmountSent();

    ////////////////////////////////////////////////////////////////////////////
    // Redemption Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address, /* operator */
        address from,
        uint256 id,
        uint256 value,
        bytes calldata /* data */
    ) external nonReentrant returns (bytes4) {
        // verify from address
        if (from == address(0)) revert FromZeroAddress();

        // protect against zero amount sent
        if (value == 0) revert ZeroAmountSent();

        // process input token
        _processInputToken(msg.sender, id, value, from);

        // sink
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        _sink(msg.sender, ids, values);

        // redeem
        _redeem(from, 1);

        // return
        return IERC1155Receiver.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address, /* operator */
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata /* data */
    ) external nonReentrant returns (bytes4) {
        // verify from address
        if (from == address(0)) revert FromZeroAddress();

        // verify array lengths match
        if (ids.length != values.length) revert ArrayLengthMismatch();

        // process input tokens
        for (uint256 i = 0; i < ids.length; ++i) {
            // protect against zero amount sent
            if (values[i] == 0) revert ZeroAmountSent();

            _processInputToken(msg.sender, ids[i], values[i], from);
        }

        // sink
        _sink(msg.sender, ids, values);

        // redeem
        _redeem(from, ids.length);

        // return
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    /// @notice Internal function to process tokens received
    function _processInputToken(
        address inputContractAddress,
        uint256 inputTokenId,
        uint256 inputAmount,
        address recipient
    ) internal virtual;

    /// @notice Function to sink the editions sent after processing the input tokens
    function _sink(address inputContractAddress, uint256[] memory inputTokenIds, uint256[] memory inputAmounts)
        internal
        virtual;

    /// @notice Function to payout after sinking the editions sent
    function _redeem(address recipient, uint256 numRedeemed) internal virtual;

    ////////////////////////////////////////////////////////////////////////////
    // Currency Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to withdraw currency from the contract in case it is sent
    /// @dev Requires owner to call the function
    function withdrawCurrency(address currencyAddress, address recipient, uint256 value)
        external
        virtual
        onlyOwner
        nonReentrant
    {
        _sendCurrency(currencyAddress, recipient, value);
    }

    /// @notice Internal helper function to send currency based on currency address and value
    function _sendCurrency(address currencyAddress, address recipient, uint256 value) internal {
        if (currencyAddress == address(0)) {
            // using Address.sendValue is fine here against griefing as it can't be used to block anyone else's actions
            payable(recipient).sendValue(value);
        } else {
            IERC20(currencyAddress).safeTransfer(recipient, value);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // ERC-721 Function
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to withdraw stuck ERC-721 tokens
    function withdrawERC721(address nftAddress, address recipient, uint256 tokenId)
        external
        virtual
        onlyOwner
        nonReentrant
    {
        IERC721(nftAddress).safeTransferFrom(address(this), recipient, tokenId);
    }

    ////////////////////////////////////////////////////////////////////////////
    // ERC-165 Function
    ////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view override(ERC165Upgradeable, IERC165) returns (bool) {
        return (ERC165Upgradeable.supportsInterface(interfaceId) || interfaceId == type(IERC1155Receiver).interfaceId);
    }
}
