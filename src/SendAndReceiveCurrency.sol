// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin-contracts-5.0.2/token/ERC20/IERC20.sol";
import {IERC1155} from "@openzeppelin-contracts-5.0.2/token/ERC1155/IERC1155.sol";
import {SendAndReceiveBase, IERC1155Receiver} from "./lib/SendAndReceiveBase.sol";

/// @title Send and Receive Currency
/// @notice A contract that receives 1155 tokens and sends back ETH or ERC-20 tokens
/// @author Transient Labs, Inc.
/// @custom:version 2.0.0
/// @dev The contract is written to only be configured for a single input token that immediately gets sent to the 0xDEAD address.
///      It is also written so that once configured, currency is always retrievable by sending tokens and nothing else.
///      There is a minimum duration that it will be open for, configured by the creator, allowing them to close it manually only after that time has passed.
///      This is all by design for security reasons.
contract SendAndReceiveCurrency is SendAndReceiveBase {
    ////////////////////////////////////////////////////////////////////////////
    // Types
    ////////////////////////////////////////////////////////////////////////////

    struct Settings {
        bool open;
        bool finalized;
        address inputContractAddress;
        uint256 inputTokenId;
        uint64 inputAmount;
        address currencyAddress;
        uint256 valuePerRedemption;
        uint64 maxRedemptions;
        uint64 numRedeemed;
        uint64 openAt;
        uint64 duration;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Storage
    ////////////////////////////////////////////////////////////////////////////

    address public constant INPUT_TOKEN_SINK = 0x000000000000000000000000000000000000dEaD;
    Settings public settings;

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////

    event EthDeposit(address indexed sender, uint256 indexed amount);

    ////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////

    error AddressZeroCodeLength();
    error ZeroInputAmount();
    error ZeroRedemptions();
    error ZeroDuration();
    error AlreadyConfigured();
    error ZeroValuePerRedemption();
    error EthDepositsClosed();
    error EthDepositNotAllowed();
    error NotOpen();
    error Finalized();
    error InvalidInputToken();
    error InvalidAmountSent();
    error NoSupplyLeft();
    error CannotFinalize();
    error RedemptionOpen();
    

    ////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////

    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    ////////////////////////////////////////////////////////////////////////////
    // Initialize
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Initialization function, meant to be called in the same transaction as the proxy deployed
    function initialize(address initOwner, Settings calldata initSettings) external initializer {
        // initialize dependencies
        __Ownable_init(initOwner);
        __ReentrancyGuard_init();

        // make sure input contract has code
        if (initSettings.inputContractAddress.code.length == 0) revert AddressZeroCodeLength();

        // make sure input amount is not zero
        if (initSettings.inputAmount == uint64(0)) revert ZeroInputAmount();

        // make sure currency address has code if not the zero address
        if (initSettings.currencyAddress != address(0) && initSettings.currencyAddress.code.length == 0) revert AddressZeroCodeLength();

        // make sure there is at least 1 redemption
        if (initSettings.maxRedemptions == uint64(0)) revert ZeroRedemptions();

        // make sure that the minimum duration > 0
        if (initSettings.duration == uint64(0)) revert ZeroDuration();

        // save settings
        Settings storage s = settings;
        s.inputContractAddress = initSettings.inputContractAddress;
        s.inputTokenId = initSettings.inputTokenId;
        s.inputAmount = initSettings.inputAmount;
        s.currencyAddress = initSettings.currencyAddress;
        s.maxRedemptions = initSettings.maxRedemptions;
        s.duration = initSettings.duration;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Redemption Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc SendAndReceiveBase
    function _processInputToken(
        address inputContractAddress,
        uint256 inputTokenId,
        uint256 inputAmount,
        address /* recipient */
    ) internal override {
        // cache settings
        Settings storage s = settings;
        uint64 numRedeemed = s.numRedeemed;

        // make sure redemption is open
        if (!s.open) revert NotOpen();
        if (s.finalized) revert Finalized();

        // make sure it's a valid token sent
        if (inputContractAddress != s.inputContractAddress || inputTokenId != s.inputTokenId) {
            revert InvalidInputToken();
        }
        if (inputAmount != uint256(s.inputAmount)) revert InvalidAmountSent();

        // make sure there is supply remaining
        if (numRedeemed >= s.maxRedemptions) revert NoSupplyLeft();

        // effects
        unchecked {
            s.numRedeemed = numRedeemed + 1;
        }
    }

    /// @inheritdoc SendAndReceiveBase
    function _sink(address inputContractAddress, uint256[] memory inputTokenIds, uint256[] memory inputAmounts)
        internal
        override
    {
        // send editions to sink
        IERC1155(inputContractAddress).safeBatchTransferFrom(
            address(this), INPUT_TOKEN_SINK, inputTokenIds, inputAmounts, ""
        );
    }

    /// @inheritdoc SendAndReceiveBase
    function _redeem(address recipient, uint256 numRedeemed) internal override {
        // cache settings
        Settings memory s = settings;

        // send money back
        uint256 totalValue = numRedeemed * s.valuePerRedemption;
        _sendCurrency(s.currencyAddress, recipient, totalValue);

        // emit event
        emit Redeemed(recipient, numRedeemed);
    }

    ////////////////////////////////////////////////////////////////////////////
    // General Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to deposit ETH
    /// @dev Anyone can call the function as a way to crowdsource funds
    /// @dev For ERC-20 deposits, there is no function needed and anyone can send funds to this address
    /// @dev Cannot be sent after the redemption is open
    /// @dev If ETH or ERC-20s are sent after the redemption is open, those funds are locked until the redemption is done
    function depositEth() external payable nonReentrant {
        // cache settings
        Settings storage s = settings;

        // if the currency is an ERC-20, revert
        if (s.currencyAddress != address(0)) revert EthDepositNotAllowed();

        // revert if the redemption is already open
        if (s.open) revert EthDepositsClosed();

        // log event
        emit EthDeposit(msg.sender, msg.value);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Owner Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to open the redemption
    /// @dev Requires owner to call the function
    /// @dev Calculates the amountPerNFT when the function is called based on the contract settings.
    /// @dev WARNING: cannot be adjusted after calling.
    function open() external onlyOwner {
        // cache settings
        Settings storage s = settings;

        // if closed, revert
        if (s.finalized) revert Finalized();

        // if open, revert
        if (s.open) revert AlreadyConfigured();

        // get balance
        uint256 balance =
            s.currencyAddress == address(0) ? address(this).balance : IERC20(s.currencyAddress).balanceOf(address(this));

        // calculate the value per redemption
        uint256 valuePerRedemption = balance / uint256(s.maxRedemptions);

        // ensure value per redemption > 0
        if (valuePerRedemption == 0) revert ZeroValuePerRedemption();

        // adjust settings
        s.open = true;
        s.openAt = uint64(block.timestamp);
        s.valuePerRedemption = valuePerRedemption;
    }

    /// @notice Function to finalize the redemption
    /// @dev Requires owner to call the function
    /// @dev This can happen only *after* the minimumDuration has passed, but the owner can set this to a very large value if desired
    /// @dev This is built to be transparent to users but allows for some economic risk mitigation
    function finalize() external onlyOwner {
        // cache settings
        Settings storage s = settings;

        // make sure can close
        if (!s.open) revert NotOpen();
        if (block.timestamp < uint256(s.openAt) + uint256(s.duration)) revert CannotFinalize();

        // save settings
        s.finalized = true;

        emit RedemptionClosed(); // reuse event from the base contract even though it uses the "closed" verbiage
    }

    /// @notice Function to withdraw currency
    /// @dev Requires owner to call the function
    /// @dev Owner can withdraw the configured currency before and after the redemption, but not during
    /// @dev Owner can withdraw any other currency at any time
    function withdrawCurrency(address currencyAddress, address recipient, uint256 value)
        external
        override
        onlyOwner
        nonReentrant
    {
        // cache settings
        Settings storage s = settings;

        // revert if it's the configured currency address, and redemption not finalized
        if (currencyAddress == s.currencyAddress && !s.finalized && s.numRedeemed < s.maxRedemptions) revert RedemptionOpen();

        // send currency to recipient
        _sendCurrency(currencyAddress, recipient, value);
    }
}
