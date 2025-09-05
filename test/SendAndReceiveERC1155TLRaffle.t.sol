// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {SendAndReceiveERC1155TLRaffle} from "src/SendAndReceiveERC1155TLRaffle.sol";
import {SendAndReceiveBase} from "src/lib/SendAndReceiveBase.sol";
import {
    OwnableUpgradeable, Initializable
} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {ERC1155TL} from "tl-creator-contracts-3.7.1/erc-1155/ERC1155TL.sol";
import {AffinePermutation} from "src/lib/AffinePermutation.sol";

contract SendAndReceiveERC1155TLRaffleTest is Test {
    SendAndReceiveERC1155TLRaffle public snr;
    ERC1155TL public nft;

    address sink = address(0x5151);
    address bsy = address(0x42069);
    address bob = address(0xB0B);
    address ace = address(0xACE);

    uint256 amt = type(uint64).max;

    uint256 openTime = 42069;

    bytes32 seed = keccak256("seed");
    string salt = "salt";
    bytes32 seedHash = keccak256(abi.encode(seed, salt));

    function setUp() public {
        // setup ERC1155TL
        nft = new ERC1155TL(false);
        nft.initialize("Token", "TKN", "", address(this), 1000, address(this), new address[](0), true, address(0));
        address[] memory addys = new address[](3);
        addys[0] = bsy;
        addys[1] = bob;
        addys[2] = ace;
        uint256[] memory amts = new uint256[](3);
        amts[0] = amt;
        amts[1] = amt;
        amts[2] = amt;
        nft.createToken("uri1", addys, amts);
        nft.createToken("uri2", addys, amts);
        nft.createToken("uri3", addys, amts);

        amts[0] = 0;
        amts[1] = 0;
        amts[2] = 0;
        nft.createToken("uri4", addys, amts);

        // setup SNR
        SendAndReceiveERC1155TLRaffle.Settings memory initSettings = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(openTime),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(10) // test :)
        });
        snr = new SendAndReceiveERC1155TLRaffle(false);
        snr.initialize(address(this), initSettings, seedHash);
        assertEq(snr.owner(), address(this));
        (
            bool canceled,
            address outputContractAddress,
            uint256 outputTokenId,
            address inputContractAddress,
            uint256 inputTokenId,
            uint64 inputAmount,
            address inputTokenSink,
            uint64 openAt,
            uint64 duration,
            uint64 numWinners,
            uint64 numEntries
        ) = snr.settings();
        assertFalse(canceled);
        assertEq(outputContractAddress, initSettings.outputContractAddress);
        assertEq(outputTokenId, initSettings.outputTokenId);
        assertEq(inputContractAddress, initSettings.inputContractAddress);
        assertEq(inputTokenId, initSettings.inputTokenId);
        assertEq(inputAmount, initSettings.inputAmount);
        assertEq(inputTokenSink, initSettings.inputTokenSink);
        assertEq(openAt, openTime);
        assertEq(duration, initSettings.duration);
        assertEq(numWinners, initSettings.numWinners);
        assertEq(numEntries, 0);

        (bytes32 retSeedHash, bytes32 retSeed, uint256 retA, uint256 retB) = snr.randomnessConfig();
        assertEq(retSeedHash, seedHash);
        assertEq(retSeed, bytes32(0));
        assertEq(retA, 0);
        assertEq(retB, 0);

        // set mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        nft.setApprovedMintContracts(mintContracts, true);
    }

    function test_initialize_initializersDisabled() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(true);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        snr2.initialize(address(this), s, seedHash);
    }

    function test_initialize_zeroInputCode() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: bsy,
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(false);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.AddressZeroCodeLength.selector);
        snr2.initialize(address(this), s, seedHash);
    }

    function test_initialize_zeroInputAmount() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 0,
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(false);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.ZeroInputAmount.selector);
        snr2.initialize(address(this), s, seedHash);
    }

    function test_initialize_zeroSink() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: address(0),
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(false);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.ZeroAddressSink.selector);
        snr2.initialize(address(this), s, seedHash);
    }

    function test_initialize_zeroOutputCode() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: bsy,
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(false);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.AddressZeroCodeLength.selector);
        snr2.initialize(address(this), s, seedHash);
    }

    function test_initialize_zeroWinners() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(0),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(false);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.ZeroWinners.selector);
        snr2.initialize(address(this), s, seedHash);
    }

    function test_initialize_zeroSeedHash() public {
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        SendAndReceiveERC1155TLRaffle snr2 = new SendAndReceiveERC1155TLRaffle(false);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.ZeroSeedHash.selector);
        snr2.initialize(address(this), s, bytes32(0));
    }

    function test_accessControl(address hacker) public {
        vm.assume(hacker != address(this));

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.updateSettings(uint64(block.timestamp), uint64(72 hours), hacker);
    }

    function test_updateSettings() public {
        // test success
        snr.updateSettings(uint64(openTime + 2), uint64(24 hours), bsy);
        (
            bool canceled,
            address outputContractAddress,
            uint256 outputTokenId,
            address inputContractAddress,
            uint256 inputTokenId,
            uint64 inputAmount,
            address inputTokenSink,
            uint64 openAt,
            uint64 duration,
            uint64 numWinners,
            uint64 numEntries
        ) = snr.settings();
        assertFalse(canceled);
        assertEq(outputContractAddress, address(nft));
        assertEq(outputTokenId, 4);
        assertEq(inputContractAddress, address(nft));
        assertEq(inputTokenId, 1);
        assertEq(inputAmount, 1);
        assertEq(inputTokenSink, bsy);
        assertEq(openAt, uint64(openTime + 2));
        assertEq(duration, uint64(24 hours));
        assertEq(numWinners, 1);
        assertEq(numEntries, 0);

        // test revert
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.ZeroAddressSink.selector);
        snr.updateSettings(uint64(openTime), uint64(24 hours), address(0));

        vm.warp(openTime + 2);

        vm.expectRevert(SendAndReceiveERC1155TLRaffle.CannotChangeOpenTimeOnceStarted.selector);
        snr.updateSettings(uint64(0), uint64(24 hours), sink);

        vm.expectRevert(SendAndReceiveERC1155TLRaffle.CannotChangeDurationOnceStarted.selector);
        snr.updateSettings(uint64(openTime + 2), uint64(12 hours), sink);

        vm.expectRevert(SendAndReceiveERC1155TLRaffle.ZeroAddressSink.selector);
        snr.updateSettings(uint64(openTime + 2), uint64(24 hours), address(0));
    }

    function test_entry_errors() public {
        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        vm.warp(openTime);

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.InvalidInputToken.selector);
        nft.safeTransferFrom(bsy, address(snr), 3, 1, "");

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.InvalidInputToken.selector);
        snr.onERC1155Received(bsy, bsy, 1, 1, "");

        // invalid input amount
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.InvalidAmountSent.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 2, "");

        // enter once, then AlreadyEntered on second send
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.AlreadyEntered.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        // window passed
        vm.warp(openTime + 48 hours + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
    }

    function test_reveal_then_enter() public {
        vm.warp(openTime);
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.prank(bob);
        nft.safeTransferFrom(bob, address(snr), 1, 1, "");
        vm.prank(ace);
        nft.safeTransferFrom(ace, address(snr), 1, 1, "");

        vm.warp(openTime + 48 hours + 1);
        snr.reveal(seed, salt);
        
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedAlreadyRevealed.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
    }

    function test_cancel_then_enter() public {
        vm.warp(openTime);
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.prank(bob);
        nft.safeTransferFrom(bob, address(snr), 1, 1, "");
        vm.prank(ace);
        nft.safeTransferFrom(ace, address(snr), 1, 1, "");

        vm.warp(openTime + 48 hours + 48 hours + 1);
        snr.cancel();
        
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.Canceled.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
    }

    function test_batch_enter_reverts_on_second_entry() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;

        vm.warp(openTime);

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.AlreadyEntered.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");
    }

    function test_batch_enter_single_array() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory values = new uint256[](1);
        values[0] = 1;

        vm.warp(openTime);

        vm.prank(bsy);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveERC1155TLRaffle.Entered(bsy, 0);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");
    }

    function test_reveal_errors() public {
        vm.warp(openTime + 100 hours);

        vm.expectRevert(SendAndReceiveERC1155TLRaffle.InvalidSeed.selector);
        snr.reveal(seed, "hiii");
    }

    function test_enter_reveal_permute(uint64 numWinners, uint64 extraEntries, uint8 inputAmount) public {
        inputAmount = uint8(bound(uint256(inputAmount), 1, 255));
        numWinners = uint64(bound(uint256(numWinners), 1, 1000));
        extraEntries = uint64(bound(uint256(extraEntries), 0, 1000));
        uint64 numEntries = numWinners + extraEntries;

        snr = new SendAndReceiveERC1155TLRaffle(false);
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: uint64(inputAmount),
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: numWinners,
            numEntries: uint64(0)
        });
        snr.initialize(address(this), s, seedHash);

        // set mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        nft.setApprovedMintContracts(mintContracts, true);

        // mint
        address[] memory addresses = new address[](numEntries);
        uint256[] memory amounts = new uint256[](numEntries);
        for (uint256 i = 0; i < numEntries; ++i) {
            addresses[i] = address(uint160(i + 10));
            amounts[i] = inputAmount;
        }
        nft.mintToken(1, addresses, amounts);

        // enter
        for (uint256 i = 0; i < numEntries; ++i) {
            vm.prank(addresses[i]);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveERC1155TLRaffle.Entered(addresses[i], i);
            nft.safeTransferFrom(addresses[i], address(snr), 1, inputAmount, "");
            SendAndReceiveERC1155TLRaffle.Entry memory entry = snr.getEntry(addresses[i]);
            assertEq(entry.index, uint64(i));
            assertTrue(entry.entered);
            assertFalse(entry.claimed);
        }

        // try to reveal
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.EntriesNotClosed.selector);
        snr.reveal(seed, salt);

        // try to claim
        vm.prank(addresses[0]);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedNotRevealed.selector);
        snr.claim(addresses[0]);

        // check winner
        assertFalse(snr.isWinner(addresses[0]));

        // warp to end
        vm.warp(block.timestamp + 49 hours);

        // try bsy enter
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, inputAmount, "");
        assertFalse(snr.isWinner(bsy));

        // reveal seed
        (uint256 A, uint256 B) = numEntries > 1 ? AffinePermutation.pickAB(uint256(numEntries), seed) : (0, 0);
        vm.expectEmit(true, true, true, false, address(snr));
        emit SendAndReceiveERC1155TLRaffle.Revealed(seed, A, B);
        snr.reveal(seed, salt);
        (bytes32 retSeedHash, bytes32 retSeed, uint256 retA, uint256 retB) = snr.randomnessConfig();
        assertEq(retSeedHash, seedHash);
        assertEq(retSeed, seed);
        assertEq(retA, A);
        assertEq(retB, B);

        // try to reveal again
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedAlreadyRevealed.selector);
        snr.reveal(seed, salt);

        // warp to end of reveal time and try to cancel
        vm.warp(block.timestamp + 48 hours + 72 hours);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedAlreadyRevealed.selector);
        snr.cancel();

        // try claiming not entered
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotEntered.selector);
        snr.claim(bsy);

        // claim
        uint256 sinkBalance = nft.balanceOf(sink, 1);
        for (uint256 i = 0; i < numEntries; ++i) {
            assertEq(nft.balanceOf(addresses[i], 1), 0);
            if (snr.isWinner(addresses[i])) {
                vm.prank(addresses[i]);
                vm.expectEmit(true, true, false, false, address(snr));
                emit SendAndReceiveBase.Redeemed(addresses[i], 1);
                snr.claim(addresses[i]);
                assertEq(nft.balanceOf(sink, 1), sinkBalance + inputAmount);
                sinkBalance = sinkBalance + inputAmount;
                assertEq(nft.balanceOf(addresses[i], 4), 1);
            } else {
                vm.expectEmit(true, false, false, false, address(snr));
                emit SendAndReceiveERC1155TLRaffle.Refunded(addresses[i]);
                snr.claim(addresses[i]);
                assertEq(nft.balanceOf(addresses[i], 1), inputAmount);
            }
            SendAndReceiveERC1155TLRaffle.Entry memory entry = snr.getEntry(addresses[i]);
            assertEq(entry.index, uint64(i));
            assertTrue(entry.entered);
            assertTrue(entry.claimed);
        }

        // try claiming again
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.AlreadyClaimed.selector);
        snr.claim(addresses[0]);
    }

    function test_enter_reveal_less_than_numWinners(uint64 numWinners, uint8 inputAmount) public {
        inputAmount = uint8(bound(uint256(inputAmount), 1, 255));
        numWinners = uint64(bound(uint256(numWinners), 1, 1000));
        uint64 numEntries = numWinners - 1;

        snr = new SendAndReceiveERC1155TLRaffle(false);
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: uint64(inputAmount),
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: numWinners,
            numEntries: uint64(0)
        });
        snr.initialize(address(this), s, seedHash);

        // set mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        nft.setApprovedMintContracts(mintContracts, true);

        // mint
        address[] memory addresses = new address[](numEntries);
        uint256[] memory amounts = new uint256[](numEntries);
        for (uint256 i = 0; i < numEntries; ++i) {
            addresses[i] = address(uint160(i + 10));
            amounts[i] = inputAmount;
        }
        if (numEntries > 0) nft.mintToken(1, addresses, amounts);

        // enter
        for (uint256 i = 0; i < numEntries; ++i) {
            vm.prank(addresses[i]);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveERC1155TLRaffle.Entered(addresses[i], i);
            nft.safeTransferFrom(addresses[i], address(snr), 1, inputAmount, "");
            SendAndReceiveERC1155TLRaffle.Entry memory entry = snr.getEntry(addresses[i]);
            assertEq(entry.index, uint64(i));
            assertTrue(entry.entered);
            assertFalse(entry.claimed);
        }

        // try to reveal
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.EntriesNotClosed.selector);
        snr.reveal(seed, salt);

        // try to claim
        if (numEntries > 0) {
            vm.prank(addresses[0]);
            vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedNotRevealed.selector);
            snr.claim(addresses[0]);
        }

        // warp to end
        vm.warp(block.timestamp + 49 hours);

        // reveal seed
        (uint256 A, uint256 B) = numEntries > 1 ? AffinePermutation.pickAB(uint256(numEntries), seed) : (0, 0);
        vm.expectEmit(true, true, true, false, address(snr));
        emit SendAndReceiveERC1155TLRaffle.Revealed(seed, A, B);
        snr.reveal(seed, salt);
        (bytes32 retSeedHash, bytes32 retSeed, uint256 retA, uint256 retB) = snr.randomnessConfig();
        assertEq(retSeedHash, seedHash);
        assertEq(retSeed, seed);
        assertEq(retA, A);
        assertEq(retB, B);

        // try to reveal again
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedAlreadyRevealed.selector);
        snr.reveal(seed, salt);

        // warp to end of reveal time and try to cancel
        vm.warp(block.timestamp + 48 hours + 72 hours);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedAlreadyRevealed.selector);
        snr.cancel();

        // try claiming not entered
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotEntered.selector);
        snr.claim(bsy);

        // claim
        uint256 sinkBalance = nft.balanceOf(sink, 1);
        for (uint256 i = 0; i < numEntries; ++i) {
            assertEq(nft.balanceOf(addresses[i], 1), 0);
            if (snr.isWinner(addresses[i])) {
                vm.prank(addresses[i]);
                vm.expectEmit(true, true, false, false, address(snr));
                emit SendAndReceiveBase.Redeemed(addresses[i], 1);
                snr.claim(addresses[i]);
                assertEq(nft.balanceOf(sink, 1), sinkBalance + inputAmount);
                sinkBalance = sinkBalance + inputAmount;
                assertEq(nft.balanceOf(addresses[i], 4), 1);
            } else {
                // should never get here
                revert("WTF IS GOING ON");
            }
            SendAndReceiveERC1155TLRaffle.Entry memory entry = snr.getEntry(addresses[i]);
            assertEq(entry.index, uint64(i));
            assertTrue(entry.entered);
            assertTrue(entry.claimed);
        }

        // try claiming again
        if (numEntries > 0) {
            vm.expectRevert(SendAndReceiveERC1155TLRaffle.AlreadyClaimed.selector);
            snr.claim(addresses[0]);
        }
    }

    function test_enter_cancel(uint64 numWinners, uint64 extraEntries, uint8 inputAmount) public {
        inputAmount = uint8(bound(uint256(inputAmount), 1, 255));
        numWinners = uint64(bound(uint256(numWinners), 1, 1000));
        extraEntries = uint64(bound(uint256(extraEntries), 0, 1000));
        uint64 numEntries = numWinners + extraEntries;

        snr = new SendAndReceiveERC1155TLRaffle(false);
        SendAndReceiveERC1155TLRaffle.Settings memory s = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: uint64(inputAmount),
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(48 hours),
            numWinners: numWinners,
            numEntries: uint64(0)
        });
        snr.initialize(address(this), s, seedHash);

        // set mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        nft.setApprovedMintContracts(mintContracts, true);

        // mint
        address[] memory addresses = new address[](numEntries);
        uint256[] memory amounts = new uint256[](numEntries);
        for (uint256 i = 0; i < numEntries; ++i) {
            addresses[i] = address(uint160(i + 10));
            amounts[i] = inputAmount;
        }
        nft.mintToken(1, addresses, amounts);

        // enter
        for (uint256 i = 0; i < numEntries; ++i) {
            vm.prank(addresses[i]);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveERC1155TLRaffle.Entered(addresses[i], i);
            nft.safeTransferFrom(addresses[i], address(snr), 1, inputAmount, "");
            SendAndReceiveERC1155TLRaffle.Entry memory entry = snr.getEntry(addresses[i]);
            assertEq(entry.index, uint64(i));
            assertTrue(entry.entered);
            assertFalse(entry.claimed);
        }

        // try to reveal
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.EntriesNotClosed.selector);
        snr.reveal(seed, salt);

        // try to claim
        vm.prank(addresses[0]);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.SeedNotRevealed.selector);
        snr.claim(addresses[0]);

        // check winner
        assertFalse(snr.isWinner(addresses[0]));

        // try to cancel
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.CannotCancel.selector);
        snr.cancel();

        // warp to end
        vm.warp(block.timestamp + 49 hours);

        // try bsy enter
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, inputAmount, "");
        assertFalse(snr.isWinner(bsy));

        // warp to end of reveal time and cancel
        vm.warp(block.timestamp + 48 hours + 72 hours);
        vm.expectEmit(address(snr));
        emit SendAndReceiveERC1155TLRaffle.RaffleCanceled();
        snr.cancel();

        // try revealing
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.Canceled.selector);
        snr.reveal(seed, salt);

        // try claiming not entered
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.NotEntered.selector);
        snr.claim(bsy);

        // claim
        for (uint256 i = 0; i < numEntries; ++i) {
            assertEq(nft.balanceOf(addresses[i], 1), 0);
            if (snr.isWinner(addresses[i])) {
                // should never get here
                revert("WTF IS POLAR BEAR DOING HERE");
            } else {
                vm.expectEmit(true, false, false, false, address(snr));
                emit SendAndReceiveERC1155TLRaffle.Refunded(addresses[i]);
                snr.claim(addresses[i]);
                assertEq(nft.balanceOf(addresses[i], 1), inputAmount);
            }
            SendAndReceiveERC1155TLRaffle.Entry memory entry = snr.getEntry(addresses[i]);
            assertEq(entry.index, uint64(i));
            assertTrue(entry.entered);
            assertTrue(entry.claimed);
        }

        // try claiming again
        vm.expectRevert(SendAndReceiveERC1155TLRaffle.AlreadyClaimed.selector);
        snr.claim(addresses[0]);
    }
}
