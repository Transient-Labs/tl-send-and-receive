// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1155} from "@openzeppelin-contracts-5.0.2/token/ERC1155/IERC1155.sol";
import {IERC1155TL} from "tl-creator-contracts-3.7.1/erc-1155/IERC1155TL.sol";
import {SendAndReceiveBase, IERC1155Receiver} from "./lib/SendAndReceiveBase.sol";

/// @title Send and Receive ERC1155TL
/// @notice A contract that receives 1155 tokens and mints back an ERC1155TL token
/// @author Transient Labs, Inc.
/// @custom:version 2.0.0
/// @dev The contract is written to only be configured for a single output token, however multiple input token configurations are possible.
///      For each token sent out, you can configure which token and what amount of that token is required.
///      Example: token A can be redeemed by sending 2 of token B *or* 5 of token C.
///      It is not possible to combine different input tokens with this contract. This is a design choice to enhance simplicity.
///      Additionally, it is possible to configure when the redemption opens, how long it lasts, and what supply there is of the redemption token.
contract SendAndReceiveERC1155TL is SendAndReceiveBase {
    ////////////////////////////////////////////////////////////////////////////
    // Types
    ////////////////////////////////////////////////////////////////////////////

    struct Settings {
        bool closed;
        address outputContractAddress;
        uint256 outputTokenId;
        address inputTokenSink;
        uint64 openAt;
        uint64 duration;
        uint64 maxRedemptions;
        uint64 numRedeemed;
    }

    struct InputConfig {
        address contractAddress;
        uint256 tokenId;
        uint256 amount;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Storage
    ////////////////////////////////////////////////////////////////////////////

    uint256 public constant MAX_INPUT_CONFIGS_PER_TX = 32;
    Settings public settings;
    mapping(address => mapping(uint256 => uint256)) private _inputAmount; // contract address => token id => number needed to redeem a mint

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////

    event InputConfigured(address indexed contractAddress, uint256 indexed tokenId, uint256 indexed amount);

    ////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////

    error AddressZeroCodeLength();
    error ZeroAddressSink();
    error ZeroRedemptions();
    error Closed();
    error NotOpen();
    error InvalidInputToken();
    error InvalidAmountSent();
    error NoSupplyLeft();
    error TooManyInputConfigs();
    error CannotChangeInputsOnceOpen();
    error CannotChangeOpenTimeOnceStarted();
    error CannotChangeDurationOnceStarted();
    error CannotChangeMaxRedemptionsOnceStarted();

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
    function initialize(address initOwner, Settings calldata initSettings, InputConfig[] calldata inputConfigs)
        external
        initializer
    {
        // initialize dependencies
        __Ownable_init(initOwner);
        __ReentrancyGuard_init();

        // verify input token sink is not the zero address
        if (initSettings.inputTokenSink == address(0)) revert ZeroAddressSink();

        // verify that the output contract address has code
        if (initSettings.outputContractAddress.code.length == 0) revert AddressZeroCodeLength();

        // verify max redemptions is > 0
        if (initSettings.maxRedemptions == 0) revert ZeroRedemptions();

        // save settings
        Settings storage s = settings;
        s.outputContractAddress = initSettings.outputContractAddress;
        s.outputTokenId = initSettings.outputTokenId;
        s.inputTokenSink = initSettings.inputTokenSink;
        s.openAt =
            uint256(initSettings.openAt) < uint64(block.timestamp) ? uint64(block.timestamp) : initSettings.openAt;
        s.duration = initSettings.duration;
        s.maxRedemptions = initSettings.maxRedemptions;

        // set input configs
        _configureInputs(inputConfigs);
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
        uint256 openAt = uint256(s.openAt);
        uint256 duration = uint256(s.duration);
        uint64 numRedeemed = s.numRedeemed;

        // make sure redemption is open
        if (s.closed) revert Closed();
        if (block.timestamp < openAt || block.timestamp > openAt + duration) {
            revert NotOpen();
        }

        // make sure it's a valid token sent
        uint256 reqInputAmount = _inputAmount[inputContractAddress][inputTokenId];
        if (reqInputAmount == 0) revert InvalidInputToken();
        if (inputAmount != reqInputAmount) revert InvalidAmountSent();

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
        // cache settings
        Settings storage s = settings;

        // send editions to sink
        IERC1155(inputContractAddress).safeBatchTransferFrom(
            address(this), s.inputTokenSink, inputTokenIds, inputAmounts, ""
        );
    }

    /// @inheritdoc SendAndReceiveBase
    function _redeem(address recipient, uint256 numRedeemed) internal override {
        // cache settings
        Settings storage s = settings;

        // mint to recipient
        address[] memory addresses = new address[](1);
        addresses[0] = recipient;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = numRedeemed;
        IERC1155TL(s.outputContractAddress).externalMint(s.outputTokenId, addresses, amounts);

        // event
        emit Redeemed(recipient, numRedeemed);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Owner Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to configure input tokens
    /// @dev Requires owner to call this function
    /// @dev Setting an amount back to 0 disables redemption using that input token
    /// @dev Cannot adjust once open
    function configureInputs(InputConfig[] calldata inputConfigs) external onlyOwner {
        Settings storage s = settings;
        if (block.timestamp >= s.openAt) revert CannotChangeInputsOnceOpen();
        _configureInputs(inputConfigs);
    }

    /// @notice Helper function to setup input configs
    function _configureInputs(InputConfig[] calldata inputConfigs) private {
        if (inputConfigs.length > MAX_INPUT_CONFIGS_PER_TX) revert TooManyInputConfigs();
        for (uint256 i = 0; i < inputConfigs.length; ++i) {
            InputConfig memory ic = inputConfigs[i];

            // ensure input contract has code
            if (ic.contractAddress.code.length == 0) revert AddressZeroCodeLength();

            // save input amount
            _inputAmount[ic.contractAddress][ic.tokenId] = ic.amount;

            emit InputConfigured(ic.contractAddress, ic.tokenId, ic.amount);
        }
    }

    /// @notice Function to update settings
    /// @dev Requires owner to call this function
    /// @dev This function limits what can be changed once open for redemptions
    function updateSettings(uint64 openAt, uint64 duration, uint64 maxRedemptions, address inputTokenSink)
        external
        onlyOwner
    {
        Settings storage s = settings;

        // checks
        if (block.timestamp >= uint256(s.openAt)) {
            if (openAt != s.openAt) revert CannotChangeOpenTimeOnceStarted();
            if (duration != s.duration) revert CannotChangeDurationOnceStarted();
            if (maxRedemptions != s.maxRedemptions) revert CannotChangeMaxRedemptionsOnceStarted();
        }
        if (inputTokenSink == address(0)) revert ZeroAddressSink();

        // adjust settings
        s.openAt = openAt;
        s.duration = duration;
        s.maxRedemptions = maxRedemptions;
        s.inputTokenSink = inputTokenSink;

        emit SettingsUpdated();
    }

    /// @notice Function to close the redemption
    /// @dev Requires owner to call this function
    /// @dev This is meant to be more of an emergency function
    function close() external onlyOwner {
        Settings storage s = settings;
        s.closed = true;

        emit RedemptionClosed();
    }

    ////////////////////////////////////////////////////////////////////////////
    // View Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to get an input amount based on the contract address and token id
    function getInputAmount(address contractAddress, uint256 tokenId) external view returns (uint256) {
        return _inputAmount[contractAddress][tokenId];
    }
}
