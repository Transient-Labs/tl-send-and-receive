// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1155} from "@openzeppelin-contracts-5.0.2/token/ERC1155/IERC1155.sol";
import {IERC1155TL} from "tl-creator-contracts-3.7.0/erc-1155/IERC1155TL.sol";
import {SendAndReceiveBase, IERC1155Receiver} from "./lib/SendAndReceiveBase.sol";
import {AffinePermutation} from "./lib/AffinePermutation.sol";

/// @title Send and Receive ERC1155TL Raffle
/// @notice A contract that receives 1155 tokens and enters senders into a raffle
/// @author Transient Labs, Inc.
/// @custom:version 2.0.0
/// @dev The contract is written to only be configured for a single output token and single input token.
///      Each address entering the onchain raffle can only enter once.
///      It uses a commit-reveal scheme + an Affine Permutation for a full onchain raffle that is unstoppable.
///      This is a design choice to enhance simplicity.
contract SendAndReceiveERC1155TLRaffle is SendAndReceiveBase {
    ////////////////////////////////////////////////////////////////////////////
    // Types
    ////////////////////////////////////////////////////////////////////////////

    struct Settings {
        bool canceled;
        address outputContractAddress;
        uint256 outputTokenId;
        address inputContractAddress;
        uint256 inputTokenId;
        uint64 inputAmount;
        address inputTokenSink;
        uint64 openAt;
        uint64 duration;
        uint64 numWinners;
        uint64 numEntries;
    }

    struct RandomnessConfig {
        bytes32 seedHash;
        bytes32 seed; // must not be bytes32(0) when revealed
        uint256 A; // affine permutation constant A
        uint256 B; // affine permutation constant B
    }

    struct Entry {
        uint64 index;
        bool entered;
        bool claimed;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Storage
    ////////////////////////////////////////////////////////////////////////////

    uint256 public constant REVEAL_TIME_ALLOTMENT = 48 hours; // 2 days to reveal the seed
    Settings public settings;
    RandomnessConfig public randomnessConfig;
    mapping(address => Entry) private _entry;

    ////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////

    event Entered(address indexed sender, uint256 indexed index);
    event Revealed(bytes32 indexed seed, uint256 indexed A, uint256 indexed B);
    event RaffleCanceled();
    event Refunded(address indexed recipient);

    ////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////

    error AddressZeroCodeLength();
    error ZeroInputAmount();
    error ZeroAddressSink();
    error ZeroWinners();
    error ZeroSeedHash();
    error NotOpen();
    error InvalidInputToken();
    error InvalidAmountSent();
    error AlreadyEntered();
    error NotEntered();
    error AlreadyClaimed();
    error EntriesNotClosed();
    error SeedNotRevealed();
    error SeedAlreadyRevealed();
    error Canceled();
    error InvalidSeed();
    error CannotCancel();
    error CannotChangeOpenTimeOnceStarted();
    error CannotChangeDurationOnceStarted();

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
    function initialize(address initOwner, Settings calldata initSettings, bytes32 seedHash) external initializer {
        // initialize dependencies
        __Ownable_init(initOwner);
        __ReentrancyGuard_init();

        // verify that the input contract address has code
        if (initSettings.inputContractAddress.code.length == 0) revert AddressZeroCodeLength();

        // make sure input amount is not 0
        if (initSettings.inputAmount == 0) revert ZeroInputAmount();

        // make sure token sink isn't the zero address
        if (initSettings.inputTokenSink == address(0)) revert ZeroAddressSink();

        // verify that the output contract address has code
        if (initSettings.outputContractAddress.code.length == 0) revert AddressZeroCodeLength();

        // make sure numWinners != 0
        if (initSettings.numWinners == uint64(0)) revert ZeroWinners();

        // make sure seed hash isn't 0
        if (seedHash == bytes32(0)) revert ZeroSeedHash();

        // save settings
        Settings storage s = settings;
        s.outputContractAddress = initSettings.outputContractAddress;
        s.outputTokenId = initSettings.outputTokenId;
        s.inputContractAddress = initSettings.inputContractAddress;
        s.inputTokenId = initSettings.inputTokenId;
        s.inputAmount = initSettings.inputAmount;
        s.inputTokenSink = initSettings.inputTokenSink;
        s.openAt =
            uint256(initSettings.openAt) < uint64(block.timestamp) ? uint64(block.timestamp) : initSettings.openAt;
        s.duration = initSettings.duration;
        s.numWinners = initSettings.numWinners;

        // save randomness config
        RandomnessConfig storage rc = randomnessConfig;
        rc.seedHash = seedHash;
    }

    ////////////////////////////////////////////////////////////////////////////
    // Redemption Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc SendAndReceiveBase
    function _processInputToken(
        address inputContractAddress,
        uint256 inputTokenId,
        uint256 inputAmount,
        address recipient
    ) internal override {
        // cache settings
        Settings storage s = settings;
        RandomnessConfig storage rc = randomnessConfig;
        uint256 openAt = uint256(s.openAt);
        uint256 duration = uint256(s.duration);
        uint64 currentIndex = s.numEntries;

        // make sure not revealed
        if (rc.seed != bytes32(0)) revert SeedAlreadyRevealed();

        // make sure not canceled
        if (s.canceled) revert Canceled();

        // make sure redemption is open
        if (block.timestamp < openAt || block.timestamp > openAt + duration) {
            revert NotOpen();
        }

        // make sure it's a valid token sent
        if (inputContractAddress != s.inputContractAddress || inputTokenId != s.inputTokenId) {
            revert InvalidInputToken();
        }
        if (inputAmount != s.inputAmount) revert InvalidAmountSent();

        // make sure they haven't already entered
        if (_entry[recipient].entered) revert AlreadyEntered();

        // add them to the entries
        Entry storage e = _entry[recipient];
        e.index = currentIndex;
        e.entered = true;

        // increment counter
        s.numEntries = currentIndex + 1;
    }

    /// @inheritdoc SendAndReceiveBase
    function _sink(
        address, /*inputContractAddress*/
        uint256[] memory, /*inputTokenIds*/
        uint256[] memory /*inputAmounts*/
    ) internal override {
        // do nothing
    }

    /// @inheritdoc SendAndReceiveBase
    function _redeem(address recipient, uint256 /* numRedeemed */ ) internal override {
        // get Entry
        Entry storage e = _entry[recipient];

        // emit event
        emit Entered(recipient, e.index);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Withdrawal Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to reveal the randomness seed and calculate A & B
    /// @dev Can be called by anyone
    /// @dev Must be called after the entries are closed
    function reveal(bytes32 seed, string calldata salt) external {
        // cache settings
        Settings storage s = settings;
        RandomnessConfig storage rc = randomnessConfig;
        uint256 openAt = uint256(s.openAt);
        uint256 duration = uint256(s.duration);

        // make sure the entries are done
        if (block.timestamp < openAt + duration) revert EntriesNotClosed();

        // make sure that the seed hasn't been committed yet
        if (rc.seed != bytes32(0)) revert SeedAlreadyRevealed();

        // check seedhash
        bytes32 calcSeedHash = keccak256(abi.encode(seed, salt));
        if (calcSeedHash != rc.seedHash) revert InvalidSeed();

        // make sure not canceled
        if (s.canceled) revert Canceled();

        // calculate A & B
        (uint256 A, uint256 B) = s.numEntries > 1 ? AffinePermutation.pickAB(s.numEntries, seed) : (0, 0);

        // store calculated values in randomness config
        rc.seed = seed;
        rc.A = A;
        rc.B = B;

        // emit log
        emit Revealed(seed, A, B);
    }

    /// @notice Function to cancel the raffle if the owner doesn't reveal in the time alloted
    /// @dev Anyone can call this as a way to protect against just locking assets
    /// @dev Can only be called after the time alloted to reveal the seed is up
    function cancel() external {
        // cache settings
        Settings storage s = settings;
        RandomnessConfig storage rc = randomnessConfig;
        uint256 openAt = uint256(s.openAt);
        uint256 duration = uint256(s.duration);

        // ensure that the time allotted to the owner is up
        if (block.timestamp < openAt + duration + REVEAL_TIME_ALLOTMENT) revert CannotCancel();

        // ensure that the seed has not been revealed
        if (rc.seed != bytes32(0)) revert SeedAlreadyRevealed();

        // cancel
        s.canceled = true;

        // emit event
        emit RaffleCanceled();
    }

    /// @notice Function to claim for a recipient, either returning their NFT or the new one
    function claim(address recipient) external nonReentrant {
        // get settings & entry
        Settings storage s = settings;
        RandomnessConfig storage rc = randomnessConfig;
        Entry storage e = _entry[recipient];
        uint256 K = uint256(s.numWinners);

        // make sure recipient has entered
        if (!e.entered) revert NotEntered();

        // make sure recipient hasn't already withdrawn
        if (e.claimed) revert AlreadyClaimed();

        // if canceled, refund immediately
        if (s.canceled) {
            e.claimed = true; // CEI
            _refund(recipient);
            return;
        }

        // make sure the seed has been submitted
        if (rc.seed == bytes32(0)) revert SeedNotRevealed();

        // save recipient as claimed
        e.claimed = true;

        // check if winner
        bool winner = (K >= s.numEntries) || (AffinePermutation.permute(e.index, s.numEntries, rc.A, rc.B) < K);

        // handle result
        if (winner) {
            _payoutWinner(recipient);
        } else {
            _refund(recipient);
        }
    }

    function _payoutWinner(address recipient) private {
        Settings storage s = settings;

        // sink editions sent
        IERC1155(s.inputContractAddress).safeTransferFrom(
            address(this), s.inputTokenSink, s.inputTokenId, s.inputAmount, ""
        );

        // mint new edition to winner
        address[] memory addresses = new address[](1);
        addresses[0] = recipient;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        IERC1155TL(s.outputContractAddress).externalMint(s.outputTokenId, addresses, amounts);

        // emit event
        emit Redeemed(recipient, 1);
    }

    function _refund(address recipient) private {
        Settings storage s = settings;

        // return back editions sent
        IERC1155(s.inputContractAddress).safeTransferFrom(address(this), recipient, s.inputTokenId, s.inputAmount, "");

        // emit event
        emit Refunded(recipient);
    }

    ////////////////////////////////////////////////////////////////////////////
    // Owner Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to update settings
    /// @dev Requires owner to call this function
    /// @dev This function limits what can be changed once open for entries
    function updateSettings(uint64 openAt, uint64 duration, address inputTokenSink) external onlyOwner {
        Settings storage s = settings;

        // checks
        if (block.timestamp >= s.openAt && openAt != s.openAt) revert CannotChangeOpenTimeOnceStarted();
        if (block.timestamp >= s.openAt && duration != s.duration) revert CannotChangeDurationOnceStarted();
        if (inputTokenSink == address(0)) revert ZeroAddressSink();

        // adjust settings
        s.openAt = openAt;
        s.duration = duration;
        s.inputTokenSink = inputTokenSink;

        emit SettingsUpdated();
    }

    ////////////////////////////////////////////////////////////////////////////
    // View Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to look up if someone has entered
    function getEntry(address user) external view returns (Entry memory) {
        return _entry[user];
    }

    /// @notice Function to get if winner
    function isWinner(address user) external view returns (bool) {
        Settings storage s = settings;
        RandomnessConfig storage rc = randomnessConfig;
        Entry storage e = _entry[user];
        if (!e.entered || rc.seed == bytes32(0) || s.canceled) return false;
        uint256 K = uint256(s.numWinners);
        return (K >= s.numEntries) || (AffinePermutation.permute(e.index, s.numEntries, rc.A, rc.B) < K);
    }
}
