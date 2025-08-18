// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {SendAndReceiveERC721} from "src/SendAndReceiveERC721.sol";
import {SendAndReceiveBase} from "src/lib/SendAndReceiveBase.sol";
import {
    OwnableUpgradeable, Initializable
} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {ERC1155TL} from "tl-creator-contracts-3.7.1/erc-1155/ERC1155TL.sol";
import {MockERC721} from "./mocks/MockERC721.sol";

contract SendAndReceiveERC721Test is Test {
    SendAndReceiveERC721 public snr;
    ERC1155TL public nft;
    MockERC721 public erc721;

    address cdb = address(0x1d1b);
    address sink = address(0x5151);
    address bsy = address(0x42069);
    address bob = address(0xB0B);
    address ace = address(0xACE);

    uint256 amt = type(uint64).max;
    uint256 openTime = 42069;

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

        // setup ERC721
        erc721 = new MockERC721(cdb);

        // setup SNR
        SendAndReceiveERC721.Settings memory initSettings = SendAndReceiveERC721.Settings({
            closed: true, // just to test :)
            outputContractAddress: address(erc721),
            outputTokenId: 1,
            inputTokenSink: sink,
            claimed: true, // just to test :)
            tokenOwner: cdb,
            openAt: uint64(openTime),
            duration: uint64(48 hours)
        });
        SendAndReceiveERC721.InputConfig[] memory inputConfigs = new SendAndReceiveERC721.InputConfig[](2);
        inputConfigs[0] = SendAndReceiveERC721.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});
        inputConfigs[1] = SendAndReceiveERC721.InputConfig({contractAddress: address(nft), tokenId: 2, amount: 2});
        snr = new SendAndReceiveERC721(false);
        snr.initialize(address(this), initSettings, inputConfigs);
        assertEq(snr.owner(), address(this));
        (
            bool closed,
            address outputContractAddress,
            uint256 outputTokenId,
            address inputTokenSink,
            bool claimed,
            address tokenOwner,
            uint64 openAt,
            uint64 duration
        ) = snr.settings();
        assertFalse(closed);
        assertEq(outputContractAddress, initSettings.outputContractAddress);
        assertEq(outputTokenId, initSettings.outputTokenId);
        assertEq(inputTokenSink, initSettings.inputTokenSink);
        assertFalse(claimed);
        assertEq(tokenOwner, cdb);
        assertEq(openAt, openTime);
        assertEq(duration, initSettings.duration);

        assertEq(snr.getInputAmount(address(nft), 1), 1, "token 1 mismatch");
        assertEq(snr.getInputAmount(address(nft), 2), 2, "token 2 mismatch");
        assertEq(snr.getInputAmount(address(nft), 3), 0, "token 3 mismatch");

        // set token approval
        vm.prank(cdb);
        erc721.approve(address(snr), 1);
    }

    function test_initialize_initializersDisabled() public {
        SendAndReceiveERC721.Settings memory s = SendAndReceiveERC721.Settings({
            closed: false,
            outputContractAddress: address(erc721),
            outputTokenId: 1,
            inputTokenSink: address(0),
            claimed: false,
            tokenOwner: cdb,
            openAt: uint64(0),
            duration: uint64(1 days)
        });
        SendAndReceiveERC721.InputConfig[] memory inputConfigs = new SendAndReceiveERC721.InputConfig[](0);
        SendAndReceiveERC721 snr2 = new SendAndReceiveERC721(true);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_initialize_zeroSink() public {
        SendAndReceiveERC721.Settings memory s = SendAndReceiveERC721.Settings({
            closed: false,
            outputContractAddress: address(erc721),
            outputTokenId: 1,
            inputTokenSink: address(0),
            claimed: false,
            tokenOwner: cdb,
            openAt: uint64(0),
            duration: uint64(1 days)
        });
        SendAndReceiveERC721.InputConfig[] memory inputConfigs = new SendAndReceiveERC721.InputConfig[](0);
        SendAndReceiveERC721 snr2 = new SendAndReceiveERC721(false);
        vm.expectRevert(SendAndReceiveERC721.ZeroAddressSink.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_initialize_zeroTokenOwner() public {
        SendAndReceiveERC721.Settings memory s = SendAndReceiveERC721.Settings({
            closed: false,
            outputContractAddress: address(erc721),
            outputTokenId: 1,
            inputTokenSink: sink,
            claimed: false,
            tokenOwner: address(0),
            openAt: uint64(0),
            duration: uint64(1 days)
        });
        SendAndReceiveERC721.InputConfig[] memory inputConfigs = new SendAndReceiveERC721.InputConfig[](0);
        SendAndReceiveERC721 snr2 = new SendAndReceiveERC721(false);
        vm.expectRevert(SendAndReceiveERC721.ZeroAddressOwner.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_initialize_outputNotContract() public {
        SendAndReceiveERC721.Settings memory s = SendAndReceiveERC721.Settings({
            closed: false,
            outputContractAddress: address(0),
            outputTokenId: 1,
            inputTokenSink: sink,
            claimed: false,
            tokenOwner: bsy,
            openAt: uint64(0),
            duration: uint64(1 days)
        });
        SendAndReceiveERC721.InputConfig[] memory inputConfigs = new SendAndReceiveERC721.InputConfig[](0);
        SendAndReceiveERC721 snr2 = new SendAndReceiveERC721(false);
        vm.expectRevert(SendAndReceiveERC721.AddressZeroCodeLength.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_accessControl(address hacker) public {
        vm.assume(hacker != address(this));

        SendAndReceiveERC721.InputConfig[] memory inputConfigs = new SendAndReceiveERC721.InputConfig[](1);
        inputConfigs[0] = SendAndReceiveERC721.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.configureInputs(inputConfigs);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.updateSettings(uint64(0), type(uint64).max, hacker, cdb);

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.close();
    }

    function test_configureInputs_errors() public {
        // too many configs
        uint256 n = 33; // > MAX_INPUT_CONFIGS_PER_TX (32)
        SendAndReceiveERC721.InputConfig[] memory arr = new SendAndReceiveERC721.InputConfig[](n);
        for (uint256 i = 0; i < n; ++i) {
            arr[i] = SendAndReceiveERC721.InputConfig({contractAddress: address(nft), tokenId: i + 10, amount: 1});
        }
        vm.expectRevert(SendAndReceiveERC721.TooManyInputConfigs.selector);
        snr.configureInputs(arr);

        arr = new SendAndReceiveERC721.InputConfig[](1);
        arr[0] = SendAndReceiveERC721.InputConfig({contractAddress: bsy, tokenId: 10, amount: 1});
        vm.expectRevert(SendAndReceiveERC721.AddressZeroCodeLength.selector);
        snr.configureInputs(arr);

        vm.warp(openTime);
        vm.expectRevert(SendAndReceiveERC721.CannotChangeInputsOnceOpen.selector);
        snr.configureInputs(arr);
    }

    function test_updateSettings_changeOpenTimeOnceStarted() public {
        vm.warp(openTime);
        vm.expectRevert(SendAndReceiveERC721.CannotChangeOpenTimeOnceStarted.selector);
        snr.updateSettings(uint64(openTime) - 1, uint64(2 days), sink, cdb);
        vm.expectRevert(SendAndReceiveERC721.CannotChangeOpenTimeOnceStarted.selector);
        snr.updateSettings(uint64(openTime) + 1, uint64(2 days), sink, cdb);
    }

    function test_updateSettings_shortenDurationOnceStarted() public {
        vm.warp(openTime);
        vm.expectRevert(SendAndReceiveERC721.CannotChangeDurationOnceStarted.selector);
        snr.updateSettings(uint64(openTime), uint64(1 hours), sink, cdb);
    }

    function test_updateSettings_zeroSink() public {
        vm.expectRevert(SendAndReceiveERC721.ZeroAddressSink.selector);
        snr.updateSettings(uint64(openTime), uint64(1 days), address(0), cdb);
        vm.warp(openTime);
        vm.expectRevert(SendAndReceiveERC721.ZeroAddressSink.selector);
        snr.updateSettings(uint64(openTime), uint64(2 days), address(0), cdb);
    }

    function test_updateSettings_zeroTokenOwner() public {
        vm.expectRevert(SendAndReceiveERC721.ZeroAddressOwner.selector);
        snr.updateSettings(uint64(openTime), uint64(1 days), sink, address(0));
        vm.warp(openTime);
        vm.expectRevert(SendAndReceiveERC721.ZeroAddressOwner.selector);
        snr.updateSettings(uint64(openTime), uint64(2 days), sink, address(0));
    }

    function test_updateSettings_updatesFields() public {
        snr.updateSettings(uint64(block.timestamp + 10), uint64(7 days), address(0xABCD), address(0xEFEF));
        (
            bool closed,
            address outputContractAddress,
            uint256 outputTokenId,
            address inputTokenSink,
            bool claimed,
            address tokenOwner,
            uint64 openAt,
            uint64 duration
        ) = snr.settings();

        assertFalse(closed);
        assertEq(outputContractAddress, address(erc721));
        assertEq(outputTokenId, 1);
        assertEq(inputTokenSink, address(0xABCD));
        assertFalse(claimed);
        assertEq(tokenOwner, address(0xEFEF));
        assertEq(openAt, uint64(block.timestamp + 10));
        assertEq(duration, uint64(7 days));
    }

    function test_singleTransfer_errors() public {
        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        // warp to open time
        vm.warp(openTime);

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.InvalidInputToken.selector);
        nft.safeTransferFrom(bsy, address(snr), 3, 1, "");

        // invalid input amount
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.InvalidAmountSent.selector);
        nft.safeTransferFrom(bsy, address(snr), 2, 1, "");

        // window passed
        vm.warp(openTime + 2 days + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
    }

    function test_singleTransfer(address sender, bool sendTokenOne) public {
        vm.assume(sender.code.length == 0);
        vm.assume(sender != address(0));
        vm.assume(sender != bsy);
        vm.assume(sender != sink);

        vm.warp(openTime);

        // mint tokens 1 & 2 to the sender
        address[] memory addresses = new address[](1);
        addresses[0] = sender;
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1;
        nft.mintToken(1, addresses, amts);
        amts[0] = 2;
        nft.mintToken(2, addresses, amts);

        if (sendTokenOne) {
            // send 1 of token 1
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 1);
            nft.safeTransferFrom(sender, address(snr), 1, 1, "");
            (,,,, bool claimed,,,) = snr.settings();
            assertTrue(claimed);
            assertEq(nft.balanceOf(sink, 1), 1);
        } else {
            // send 2 of token 2
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 1);
            nft.safeTransferFrom(sender, address(snr), 2, 2, "");
            (,,,, bool claimed,,,) = snr.settings();
            assertTrue(claimed);
            assertEq(nft.balanceOf(sink, 2), 2);
        }

        // check final results
        assertEq(erc721.ownerOf(1), sender);

        // try to claim again
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.AlreadyClaimed.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.AlreadyClaimed.selector);
        nft.safeTransferFrom(bsy, address(snr), 2, 2, "");
    }

    function test_batchTransfer_errors() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // warp to open time
        vm.warp(openTime);

        // invalid input token
        ids[0] = 3;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // invalid input amount
        ids[0] = 1;
        values[0] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // window passed
        values[0] = 1;
        vm.warp(openTime + 2 days + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");
    }

    function test_batchTransfer(address sender) public {
        vm.assume(sender.code.length == 0);
        vm.assume(sender != address(0));
        vm.assume(sender != bsy);
        vm.assume(sender != sink);

        vm.warp(openTime);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        // mint tokens 1 & 2 to the sender
        address[] memory addresses = new address[](1);
        addresses[0] = sender;
        uint256[] memory amts = new uint256[](1);
        amts[0] = 1;
        nft.mintToken(1, addresses, amts);
        amts[0] = 2;
        nft.mintToken(2, addresses, amts);

        // should always fail on batch transfer
        vm.prank(sender);
        vm.expectRevert(SendAndReceiveERC721.AlreadyClaimed.selector);
        nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
    }

    function test_closed_errors() public {
        snr.close();

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.Closed.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721.Closed.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");
    }
}
