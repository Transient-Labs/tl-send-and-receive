// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SendAndReceiveBase} from "src/lib/SendAndReceiveBase.sol";

contract MockSendAndReceive is SendAndReceiveBase {
    event Processing();
    event Sinking();
    event Redeeming();

    receive() external payable {
        // allow ETH to be sent to this one
    }

    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /// @notice Initialization function, meant to be called in the same transaction as the proxy deployed
    function initialize(address initOwner) external initializer {
        // initialize dependencies
        __Ownable_init(initOwner);
        __ReentrancyGuard_init();
    }

    function _processInputToken(
        address, /*inputContractAddress*/
        uint256, /*inputTokenId*/
        uint256, /*inputAmount*/
        address /*recipient*/
    ) internal override {
        // allow all
        emit Processing();
    }

    /// @notice Function to sink the editions sent after processing the input tokens
    function _sink(
        address, /*inputContractAddress*/
        uint256[] memory, /*inputTokenIds*/
        uint256[] memory /*inputAmounts*/
    ) internal override {
        // do nothing
        emit Sinking();
    }

    /// @notice Function to payout after sinking the editions sent
    function _redeem(address, /*recipient*/ uint256 /*numRedeemed*/ ) internal override {
        // do nothing
        emit Redeeming();
    }
}
