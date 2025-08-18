// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {SendAndReceiveERC1155TL} from "src/SendAndReceiveERC1155TL.sol";
import {SendAndReceiveBase} from "src/lib/SendAndReceiveBase.sol";
import {
    OwnableUpgradeable, Initializable
} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {ERC1155TL} from "tl-creator-contracts-3.7.0/erc-1155/ERC1155TL.sol";

contract SendAndReceiveERC1155TLTest is Test {
    SendAndReceiveERC1155TL public snr;
    ERC1155TL public nft;

    address sink = address(0x5151);
    address bsy = address(0x42069);
    address bob = address(0xB0B);
    address ace = address(0xACE);

    uint256 amt = type(uint64).max;

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
        SendAndReceiveERC1155TL.Settings memory initSettings = SendAndReceiveERC1155TL.Settings({
            closed: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputTokenSink: sink,
            openAt: uint64(block.timestamp + 1 days),
            duration: uint64(48 hours),
            maxRedemptions: uint64(100),
            numRedeemed: uint64(0)
        });
        SendAndReceiveERC1155TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC1155TL.InputConfig[](2);
        inputConfigs[0] = SendAndReceiveERC1155TL.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});
        inputConfigs[1] = SendAndReceiveERC1155TL.InputConfig({contractAddress: address(nft), tokenId: 2, amount: 2});
        snr = new SendAndReceiveERC1155TL(false);
        snr.initialize(address(this), initSettings, inputConfigs);
        assertEq(snr.owner(), address(this));
        (
            bool closed,
            address outputContractAddress,
            uint256 outputTokenId,
            address inputTokenSink,
            uint64 openAt,
            uint64 duration,
            uint64 maxRedemptions,
            uint64 numRedeemed
        ) = snr.settings();
        assertFalse(closed);
        assertEq(outputContractAddress, initSettings.outputContractAddress);
        assertEq(outputTokenId, initSettings.outputTokenId);
        assertEq(inputTokenSink, initSettings.inputTokenSink);
        assertEq(openAt, block.timestamp + 1 days);
        assertEq(duration, initSettings.duration);
        assertEq(maxRedemptions, initSettings.maxRedemptions);
        assertEq(numRedeemed, 0);

        assertEq(snr.getInputAmount(address(nft), 1), 1, "token 1 mismatch");
        assertEq(snr.getInputAmount(address(nft), 2), 2, "token 2 mismatch");
        assertEq(snr.getInputAmount(address(nft), 3), 0, "token 3 mismatch");

        // set mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        nft.setApprovedMintContracts(mintContracts, true);
    }

    function test_initialize_initializersDisabled() public {
        SendAndReceiveERC1155TL.Settings memory s = SendAndReceiveERC1155TL.Settings({
            closed: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputTokenSink: address(0),
            openAt: uint64(0),
            duration: uint64(1 days),
            maxRedemptions: uint64(5),
            numRedeemed: uint64(0)
        });
        SendAndReceiveERC1155TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC1155TL.InputConfig[](0);
        SendAndReceiveERC1155TL snr2 = new SendAndReceiveERC1155TL(true);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_initialize_errors() public {
        SendAndReceiveERC1155TL.Settings memory s = SendAndReceiveERC1155TL.Settings({
            closed: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputTokenSink: address(0),
            openAt: uint64(0),
            duration: uint64(1 days),
            maxRedemptions: uint64(5),
            numRedeemed: uint64(0)
        });
        SendAndReceiveERC1155TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC1155TL.InputConfig[](0);
        SendAndReceiveERC1155TL snr2 = new SendAndReceiveERC1155TL(false);

        // zero sink
        vm.expectRevert(SendAndReceiveERC1155TL.ZeroAddressSink.selector);
        snr2.initialize(address(this), s, inputConfigs);

        // output zero contract code
        s.inputTokenSink = sink;
        s.outputContractAddress = bsy;
        vm.expectRevert(SendAndReceiveERC1155TL.AddressZeroCodeLength.selector);
        snr2.initialize(address(this), s, inputConfigs);

        // zero redemptions
        s.outputContractAddress = address(nft);
        s.maxRedemptions = uint64(0);
        vm.expectRevert(SendAndReceiveERC1155TL.ZeroRedemptions.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_accessControl(address hacker) public {
        vm.assume(hacker != address(this));

        SendAndReceiveERC1155TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC1155TL.InputConfig[](1);
        inputConfigs[0] = SendAndReceiveERC1155TL.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.configureInputs(inputConfigs);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.updateSettings(uint64(0), type(uint64).max, uint64(1_000_000), hacker);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.close();
    }

    function test_configureInputs_errors() public {
        // too many configs
        uint256 n = 33; // > MAX_INPUT_CONFIGS_PER_TX (32)
        SendAndReceiveERC1155TL.InputConfig[] memory arr = new SendAndReceiveERC1155TL.InputConfig[](n);
        for (uint256 i = 0; i < n; ++i) {
            arr[i] = SendAndReceiveERC1155TL.InputConfig({contractAddress: address(nft), tokenId: i + 10, amount: 1});
        }
        vm.expectRevert(SendAndReceiveERC1155TL.TooManyInputConfigs.selector);
        snr.configureInputs(arr);

        arr = new SendAndReceiveERC1155TL.InputConfig[](1);
        arr[0] = SendAndReceiveERC1155TL.InputConfig({contractAddress: bsy, tokenId: 10, amount: 1});
        vm.expectRevert(SendAndReceiveERC1155TL.AddressZeroCodeLength.selector);
        snr.configureInputs(arr);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeInputsOnceOpen.selector);
        snr.configureInputs(arr);
    }

    function test_updateSettings() public {
        SendAndReceiveERC1155TL.Settings memory s = SendAndReceiveERC1155TL.Settings({
            closed: false,
            outputContractAddress: address(nft),
            outputTokenId: 4,
            inputTokenSink: sink,
            openAt: uint64(block.timestamp + 1 days),
            duration: uint64(1 days),
            maxRedemptions: uint64(5),
            numRedeemed: uint64(0)
        });
        SendAndReceiveERC1155TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC1155TL.InputConfig[](0);
        SendAndReceiveERC1155TL snr2 = new SendAndReceiveERC1155TL(false);
        snr2.initialize(address(this), s, inputConfigs);
        (
            ,
            ,
            ,
            address inputTokenSink,
            uint64 openAt,
            uint64 duration,
            uint64 maxRedemptions,
        ) = snr2.settings();

        // adjust settings before open
        snr2.updateSettings(uint64(block.timestamp + 1 days), uint64(2 days), uint64(10), bsy);
         (
            ,
            ,
            ,
            inputTokenSink,
            openAt,
            duration,
            maxRedemptions,
        ) = snr2.settings();
        assertEq(inputTokenSink, bsy);
        assertEq(openAt, block.timestamp + uint64(1 days));
        assertEq(duration, uint64(2 days));
        assertEq(maxRedemptions, uint64(10));

        // zero sink error
        vm.expectRevert(SendAndReceiveERC1155TL.ZeroAddressSink.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions, address(0));

        // change open time error
        vm.warp(openAt);
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeOpenTimeOnceStarted.selector);
        snr2.updateSettings(uint64(openAt - 1), duration, maxRedemptions, inputTokenSink);
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeOpenTimeOnceStarted.selector);
        snr2.updateSettings(uint64(openAt + 1), duration, maxRedemptions, inputTokenSink);

        // cannot chain duration
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeDurationOnceStarted.selector);
        snr2.updateSettings(openAt, duration - uint64(1), maxRedemptions, inputTokenSink);
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeDurationOnceStarted.selector);
        snr2.updateSettings(openAt, duration + uint64(1), maxRedemptions, inputTokenSink);

        // cannot change redemptions once opened
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeMaxRedemptionsOnceStarted.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions - uint64(1), inputTokenSink);
        vm.expectRevert(SendAndReceiveERC1155TL.CannotChangeMaxRedemptionsOnceStarted.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions + uint64(1), inputTokenSink);

        // zero sink error
        vm.expectRevert(SendAndReceiveERC1155TL.ZeroAddressSink.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions, address(0));

        // can change sink address once open
        snr2.updateSettings(openAt, duration, maxRedemptions, sink);
        (
            ,
            ,
            ,
            inputTokenSink,
            openAt,
            duration,
            maxRedemptions,
        ) = snr2.settings();
        assertEq(inputTokenSink, sink);
    }

    function test_singleTransfer_errors() public {
        (
            ,
            ,
            ,
            ,
            uint64 openAt,
            uint64 duration,
            ,
        ) = snr.settings();

        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        // warp to open time
        vm.warp(openAt);

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.InvalidInputToken.selector);
        nft.safeTransferFrom(bsy, address(snr), 3, 1, "");

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.InvalidInputToken.selector);
        snr.onERC1155Received(bsy, bsy, 1, 1, "");

        // invalid input amount
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.InvalidAmountSent.selector);
        nft.safeTransferFrom(bsy, address(snr), 2, 1, "");

        // window passed
        vm.warp(openAt + duration + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
    }

    function test_singleTransfer(address sender, uint256 amt1, uint256 amt2) public {
        vm.assume(sender.code.length == 0);
        vm.assume(sender != address(0));
        vm.assume(sender != bsy);
        vm.assume(sender != sink);

        amt1 = bound(amt1, 1, 1000);
        amt2 = bound(amt2, 2, 1000);
        if (amt2 % 2 != 0) amt2 -= 1;

        // warp to start time
        vm.warp(block.timestamp + 1 days);

        // mint tokens 1 & 2 to the sender
        address[] memory addresses = new address[](1);
        addresses[0] = sender;
        uint256[] memory amts = new uint256[](1);
        amts[0] = amt1;
        nft.mintToken(1, addresses, amts);
        amts[0] = amt2;
        nft.mintToken(2, addresses, amts);

        // send 1 of token 1
        vm.prank(sender);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveBase.Redeemed(sender, 1);
        nft.safeTransferFrom(sender, address(snr), 1, 1, "");
        (,,,,,,, uint64 numRedeemed) = snr.settings();
        assertEq(numRedeemed, 1);

        // send 2 of token 2
        vm.prank(sender);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveBase.Redeemed(sender, 1);
        nft.safeTransferFrom(sender, address(snr), 2, 2, "");
        (,,,,,,, numRedeemed) = snr.settings();
        assertEq(numRedeemed, 2);

        uint256 totalRedeemed = 2;

        // loop through rest of token 1
        for (uint256 i = 1; i < amt1; i++) {
            if (totalRedeemed == 100) break;
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 1);
            nft.safeTransferFrom(sender, address(snr), 1, 1, "");
            totalRedeemed++;
            (,,,,,,, numRedeemed) = snr.settings();
            assertEq(numRedeemed, totalRedeemed);
            assertEq(nft.balanceOf(sink, 1), i + 1);
        }

        // loop through rest of token 2
        for (uint256 i = 2; i < amt2; i += 2) {
            if (totalRedeemed == 100) break;
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 1);
            nft.safeTransferFrom(sender, address(snr), 2, 2, "");
            totalRedeemed++;
            (,,,,,,, numRedeemed) = snr.settings();
            assertEq(numRedeemed, totalRedeemed);
            assertEq(nft.balanceOf(sink, 2), i + 2);
        }

        if (totalRedeemed == 100) {
            // make sure supply limit works
            vm.prank(bsy);
            vm.expectRevert(SendAndReceiveERC1155TL.NoSupplyLeft.selector);
            nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        }

        // check outputs
        assertEq(nft.balanceOf(sender, 4), totalRedeemed, "sender didn't get all the redemptions they should");
    }

    function test_batchTransfer_errors() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        (
            ,
            ,
            ,
            ,
            uint64 openAt,
            uint64 duration,
            ,
        ) = snr.settings();

        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        vm.warp(openAt);

        // invalid input token
        ids[0] = 3;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.InvalidInputToken.selector);
        snr.onERC1155BatchReceived(bsy, bsy, ids, values, "");

        // invalid input amount
        ids[0] = 1;
        values[0] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // window passed
        values[0] = 1;
        vm.warp(openAt + duration + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");  
    }

    function test_batchTransfer(address sender, uint256 amt1) public {
        vm.assume(sender.code.length == 0);
        vm.assume(sender != address(0));
        vm.assume(sender != bsy);
        vm.assume(sender != sink);

        amt1 = bound(amt1, 1, 1000);
        uint256 amt2 = amt1 * 2;

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        // warp to start time
        vm.warp(block.timestamp + 1 days);

        // mint tokens 1 & 2 to the sender
        address[] memory addresses = new address[](1);
        addresses[0] = sender;
        uint256[] memory amts = new uint256[](1);
        amts[0] = amt1;
        nft.mintToken(1, addresses, amts);
        amts[0] = amt2;
        nft.mintToken(2, addresses, amts);

        // redeem one of each
        vm.prank(sender);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveBase.Redeemed(sender, 2);
        nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
        (,,,,,,, uint64 numRedeemed) = snr.settings();
        assertEq(numRedeemed, 2);

        uint256 totalRedeemed = 2;

        // loop through rest
        for (uint256 i = 1; i < amt1; i++) {
            if (totalRedeemed == 100) break;
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 2);
            nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
            totalRedeemed += 2;
            (,,,,,,, numRedeemed) = snr.settings();
            assertEq(numRedeemed, totalRedeemed);
            assertEq(nft.balanceOf(sink, 1), i + 1);
            assertEq(nft.balanceOf(sink, 2), i * 2 + 2);
        }

        if (totalRedeemed == 100) {
            // make sure supply limit works
            vm.prank(bsy);
            vm.expectRevert(SendAndReceiveERC1155TL.NoSupplyLeft.selector);
            nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        }

        // check outputs
        assertEq(nft.balanceOf(sender, 4), totalRedeemed, "sender didn't get all the redemptions they should");
    }

    function test_closed_errors() public {
        snr.close();

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.Closed.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC1155TL.Closed.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");
    }

    function test_locked_ERC1155TL() public {
        // locked tokens on ERC1155TL only applies to minting new supply and doesn't impact transfers
        // this just verifies that functionality in addition to the tests in the creator contracts repo
        nft.lockToken(1);
        nft.lockToken(2);

        vm.warp(block.timestamp + 1 days);

        address[] memory addresses = new address[](1);
        addresses[0] = bsy;
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1;

        vm.expectRevert();
        nft.mintToken(1, addresses, amts);

        vm.prank(bsy);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveBase.Redeemed(bsy, 1);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        vm.prank(bsy);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveBase.Redeemed(bsy, 2);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // expect mint failure if locked
        nft.lockToken(4);
        vm.prank(bsy);
        vm.expectRevert(ERC1155TL.TokenLocked.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
    }
}
