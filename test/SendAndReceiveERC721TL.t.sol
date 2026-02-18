// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {SendAndReceiveERC721TL} from "src/SendAndReceiveERC721TL.sol";
import {SendAndReceiveBase} from "src/lib/SendAndReceiveBase.sol";
import {
    OwnableUpgradeable, Initializable
} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {ERC1155TL} from "tl-creator-contracts-3.7.1/erc-1155/ERC1155TL.sol";
import {ERC721TL} from "tl-creator-contracts-3.7.1/erc-721/ERC721TL.sol";

contract SendAndReceiveERC721TLTest is Test {
    SendAndReceiveERC721TL public snr;
    ERC1155TL public nft;
    ERC721TL public outputNft;

    address sink = address(0x5151);
    address bsy = address(0x42069);
    address bob = address(0xB0B);
    address ace = address(0xACE);

    uint256 amt = type(uint64).max;
    string constant BASE_URI = "ipfs://base-folder";

    function setUp() public {
        // setup ERC1155TL input token
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

        // setup ERC721TL output token
        outputNft = new ERC721TL(false);
        outputNft.initialize("Output", "OUT", "", address(this), 0, address(this), new address[](0), true, address(0), address(0));

        // setup SNR
        SendAndReceiveERC721TL.Settings memory initSettings = SendAndReceiveERC721TL.Settings({
            closed: false,
            outputContractAddress: address(outputNft),
            inputTokenSink: sink,
            openAt: uint64(block.timestamp + 1 days),
            duration: uint64(48 hours),
            maxRedemptions: uint64(100),
            numRedeemed: uint64(0),
            nextUriIndex: uint64(0),
            baseUri: BASE_URI
        });
        SendAndReceiveERC721TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC721TL.InputConfig[](2);
        inputConfigs[0] = SendAndReceiveERC721TL.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});
        inputConfigs[1] = SendAndReceiveERC721TL.InputConfig({contractAddress: address(nft), tokenId: 2, amount: 2});
        snr = new SendAndReceiveERC721TL(false);
        snr.initialize(address(this), initSettings, inputConfigs);
        assertEq(snr.owner(), address(this));

        (
            bool closed,
            address outputContractAddress,
            address inputTokenSink,
            uint64 openAt,
            uint64 duration,
            uint64 maxRedemptions,
            uint64 numRedeemed,
            uint64 nextUriIndex,
            string memory baseUri
        ) = snr.settings();
        assertFalse(closed);
        assertEq(outputContractAddress, initSettings.outputContractAddress);
        assertEq(inputTokenSink, initSettings.inputTokenSink);
        assertEq(openAt, block.timestamp + 1 days);
        assertEq(duration, initSettings.duration);
        assertEq(maxRedemptions, initSettings.maxRedemptions);
        assertEq(numRedeemed, 0);
        assertEq(nextUriIndex, 0);
        assertEq(baseUri, BASE_URI);

        assertEq(snr.getInputAmount(address(nft), 1), 1, "token 1 mismatch");
        assertEq(snr.getInputAmount(address(nft), 2), 2, "token 2 mismatch");
        assertEq(snr.getInputAmount(address(nft), 3), 0, "token 3 mismatch");

        // set approved mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        outputNft.setApprovedMintContracts(mintContracts, true);
    }

    function test_initialize_initializersDisabled() public {
        SendAndReceiveERC721TL.Settings memory s = SendAndReceiveERC721TL.Settings({
            closed: false,
            outputContractAddress: address(outputNft),
            inputTokenSink: sink,
            openAt: uint64(0),
            duration: uint64(1 days),
            maxRedemptions: uint64(5),
            numRedeemed: uint64(0),
            nextUriIndex: uint64(0),
            baseUri: BASE_URI
        });
        SendAndReceiveERC721TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC721TL.InputConfig[](0);
        SendAndReceiveERC721TL snr2 = new SendAndReceiveERC721TL(true);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_initialize_errors() public {
        SendAndReceiveERC721TL.Settings memory s = SendAndReceiveERC721TL.Settings({
            closed: false,
            outputContractAddress: address(outputNft),
            inputTokenSink: address(0),
            openAt: uint64(0),
            duration: uint64(1 days),
            maxRedemptions: uint64(5),
            numRedeemed: uint64(0),
            nextUriIndex: uint64(0),
            baseUri: BASE_URI
        });
        SendAndReceiveERC721TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC721TL.InputConfig[](0);
        SendAndReceiveERC721TL snr2 = new SendAndReceiveERC721TL(false);

        // zero sink
        vm.expectRevert(SendAndReceiveERC721TL.ZeroAddressSink.selector);
        snr2.initialize(address(this), s, inputConfigs);

        // output zero contract code
        s.inputTokenSink = sink;
        s.outputContractAddress = bsy;
        vm.expectRevert(SendAndReceiveERC721TL.AddressZeroCodeLength.selector);
        snr2.initialize(address(this), s, inputConfigs);

        // zero redemptions
        s.outputContractAddress = address(outputNft);
        s.maxRedemptions = uint64(0);
        vm.expectRevert(SendAndReceiveERC721TL.ZeroRedemptions.selector);
        snr2.initialize(address(this), s, inputConfigs);
    }

    function test_accessControl(address hacker) public {
        vm.assume(hacker != address(this));

        SendAndReceiveERC721TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC721TL.InputConfig[](1);
        inputConfigs[0] = SendAndReceiveERC721TL.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});

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
        SendAndReceiveERC721TL.InputConfig[] memory arr = new SendAndReceiveERC721TL.InputConfig[](n);
        for (uint256 i = 0; i < n; ++i) {
            arr[i] = SendAndReceiveERC721TL.InputConfig({contractAddress: address(nft), tokenId: i + 10, amount: 1});
        }
        vm.expectRevert(SendAndReceiveERC721TL.TooManyInputConfigs.selector);
        snr.configureInputs(arr);

        arr = new SendAndReceiveERC721TL.InputConfig[](1);
        arr[0] = SendAndReceiveERC721TL.InputConfig({contractAddress: bsy, tokenId: 10, amount: 1});
        vm.expectRevert(SendAndReceiveERC721TL.AddressZeroCodeLength.selector);
        snr.configureInputs(arr);

        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeInputsOnceOpen.selector);
        snr.configureInputs(arr);
    }

    function test_updateSettings() public {
        SendAndReceiveERC721TL.Settings memory s = SendAndReceiveERC721TL.Settings({
            closed: false,
            outputContractAddress: address(outputNft),
            inputTokenSink: sink,
            openAt: uint64(block.timestamp + 1 days),
            duration: uint64(1 days),
            maxRedemptions: uint64(5),
            numRedeemed: uint64(0),
            nextUriIndex: uint64(0),
            baseUri: BASE_URI
        });
        SendAndReceiveERC721TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC721TL.InputConfig[](0);
        SendAndReceiveERC721TL snr2 = new SendAndReceiveERC721TL(false);
        snr2.initialize(address(this), s, inputConfigs);
        (,,, uint64 openAt, uint64 duration, uint64 maxRedemptions,,,) = snr2.settings();
        (, , address inputTokenSink, , , , , , ) = snr2.settings();

        // adjust settings before open
        snr2.updateSettings(uint64(block.timestamp + 1 days), uint64(2 days), uint64(10), bsy);
        (,,, openAt, duration, maxRedemptions,,,) = snr2.settings();
        (, , inputTokenSink, , , , , , ) = snr2.settings();
        assertEq(inputTokenSink, bsy);
        assertEq(openAt, block.timestamp + uint64(1 days));
        assertEq(duration, uint64(2 days));
        assertEq(maxRedemptions, uint64(10));

        // zero sink error
        vm.expectRevert(SendAndReceiveERC721TL.ZeroAddressSink.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions, address(0));

        // change open time error
        vm.warp(openAt);
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeOpenTimeOnceStarted.selector);
        snr2.updateSettings(uint64(openAt - 1), duration, maxRedemptions, inputTokenSink);
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeOpenTimeOnceStarted.selector);
        snr2.updateSettings(uint64(openAt + 1), duration, maxRedemptions, inputTokenSink);

        // cannot change duration once opened
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeDurationOnceStarted.selector);
        snr2.updateSettings(openAt, duration - uint64(1), maxRedemptions, inputTokenSink);
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeDurationOnceStarted.selector);
        snr2.updateSettings(openAt, duration + uint64(1), maxRedemptions, inputTokenSink);

        // cannot change redemptions once opened
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeMaxRedemptionsOnceStarted.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions - uint64(1), inputTokenSink);
        vm.expectRevert(SendAndReceiveERC721TL.CannotChangeMaxRedemptionsOnceStarted.selector);
        snr2.updateSettings(openAt, duration, maxRedemptions + uint64(1), inputTokenSink);

        // can change sink address once open
        snr2.updateSettings(openAt, duration, maxRedemptions, sink);
        (, , inputTokenSink, , , , , , ) = snr2.settings();
        assertEq(inputTokenSink, sink);
    }

    function test_singleTransfer_errors() public {
        (,,, uint64 openAt, uint64 duration, , , , ) = snr.settings();

        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        // warp to open time
        vm.warp(openAt);

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.InvalidInputToken.selector);
        nft.safeTransferFrom(bsy, address(snr), 3, 1, "");

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.InvalidInputToken.selector);
        snr.onERC1155Received(bsy, bsy, 1, 1, "");

        // invalid input amount
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.InvalidAmountSent.selector);
        nft.safeTransferFrom(bsy, address(snr), 2, 1, "");

        // window passed
        vm.warp(openAt + duration + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.NotOpen.selector);
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
        (, , , , , , uint64 numRedeemed, uint64 nextUriIndex, ) = snr.settings();
        assertEq(numRedeemed, 1);
        assertEq(nextUriIndex, 1);
        assertEq(outputNft.tokenURI(1), string.concat(BASE_URI, "/0"));

        // send 2 of token 2
        vm.prank(sender);
        vm.expectEmit(true, true, false, false, address(snr));
        emit SendAndReceiveBase.Redeemed(sender, 1);
        nft.safeTransferFrom(sender, address(snr), 2, 2, "");
        (, , , , , , numRedeemed, nextUriIndex, ) = snr.settings();
        assertEq(numRedeemed, 2);
        assertEq(nextUriIndex, 2);
        assertEq(outputNft.tokenURI(2), string.concat(BASE_URI, "/1"));

        uint256 totalRedeemed = 2;

        // loop through rest of token 1
        for (uint256 i = 1; i < amt1; i++) {
            if (totalRedeemed == 100) break;
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 1);
            nft.safeTransferFrom(sender, address(snr), 1, 1, "");
            totalRedeemed++;
            (, , , , , , numRedeemed, nextUriIndex, ) = snr.settings();
            assertEq(numRedeemed, totalRedeemed);
            assertEq(nextUriIndex, totalRedeemed);
            assertEq(nft.balanceOf(sink, 1), i + 1);
            assertEq(outputNft.tokenURI(totalRedeemed), string.concat(BASE_URI, "/", vm.toString(totalRedeemed - 1)));
        }

        // loop through rest of token 2
        for (uint256 i = 2; i < amt2; i += 2) {
            if (totalRedeemed == 100) break;
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 1);
            nft.safeTransferFrom(sender, address(snr), 2, 2, "");
            totalRedeemed++;
            (, , , , , , numRedeemed, nextUriIndex, ) = snr.settings();
            assertEq(numRedeemed, totalRedeemed);
            assertEq(nextUriIndex, totalRedeemed);
            assertEq(nft.balanceOf(sink, 2), i + 2);
            assertEq(outputNft.tokenURI(totalRedeemed), string.concat(BASE_URI, "/", vm.toString(totalRedeemed - 1)));
        }

        if (totalRedeemed == 100) {
            // make sure supply limit works
            vm.prank(bsy);
            vm.expectRevert(SendAndReceiveERC721TL.NoSupplyLeft.selector);
            nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        }

        // check outputs
        assertEq(outputNft.totalSupply(), totalRedeemed);
        assertEq(outputNft.balanceOf(sender), totalRedeemed, "sender didn't get all the redemptions they should");
        assertEq(outputNft.tokenURI(1), string.concat(BASE_URI, "/0"));
        assertEq(outputNft.tokenURI(totalRedeemed), string.concat(BASE_URI, "/", vm.toString(totalRedeemed - 1)));
    }

    function test_batchTransfer_errors() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        (,,, uint64 openAt, uint64 duration, , , , ) = snr.settings();

        // not open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        vm.warp(openAt);

        // invalid input token
        ids[0] = 3;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // invalid input token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.InvalidInputToken.selector);
        snr.onERC1155BatchReceived(bsy, bsy, ids, values, "");

        // invalid input amount
        ids[0] = 1;
        values[0] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        // window passed
        values[0] = 1;
        vm.warp(openAt + duration + 1);
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.NotOpen.selector);
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
        (, , , , , , uint64 numRedeemed, uint64 nextUriIndex, ) = snr.settings();
        assertEq(numRedeemed, 2);
        assertEq(nextUriIndex, 2);
        assertEq(outputNft.tokenURI(1), string.concat(BASE_URI, "/0"));
        assertEq(outputNft.tokenURI(2), string.concat(BASE_URI, "/1"));

        uint256 totalRedeemed = 2;

        // loop through rest
        for (uint256 i = 1; i < amt1; i++) {
            if (totalRedeemed == 100) break;
            vm.prank(sender);
            vm.expectEmit(true, true, false, false, address(snr));
            emit SendAndReceiveBase.Redeemed(sender, 2);
            nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
            totalRedeemed += 2;
            (, , , , , , numRedeemed, nextUriIndex, ) = snr.settings();
            assertEq(numRedeemed, totalRedeemed);
            assertEq(nextUriIndex, totalRedeemed);
            assertEq(nft.balanceOf(sink, 1), i + 1);
            assertEq(nft.balanceOf(sink, 2), i * 2 + 2);
            assertEq(outputNft.tokenURI(totalRedeemed - 1), string.concat(BASE_URI, "/", vm.toString(totalRedeemed - 2)));
            assertEq(outputNft.tokenURI(totalRedeemed), string.concat(BASE_URI, "/", vm.toString(totalRedeemed - 1)));
        }

        if (totalRedeemed == 100) {
            // make sure supply limit works
            vm.prank(bsy);
            vm.expectRevert(SendAndReceiveERC721TL.NoSupplyLeft.selector);
            nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        }

        // check outputs
        assertEq(outputNft.totalSupply(), totalRedeemed);
        assertEq(outputNft.balanceOf(sender), totalRedeemed, "sender didn't get all the redemptions they should");
        assertEq(outputNft.tokenURI(1), string.concat(BASE_URI, "/0"));
        assertEq(outputNft.tokenURI(totalRedeemed), string.concat(BASE_URI, "/", vm.toString(totalRedeemed - 1)));
    }

    function test_closed_errors() public {
        snr.close();

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.Closed.selector);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveERC721TL.Closed.selector);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");
    }

    function test_uriIndexProgression() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        assertEq(outputNft.ownerOf(1), bsy);
        assertEq(outputNft.tokenURI(1), string.concat(BASE_URI, "/0"));

        vm.prank(bob);
        nft.safeTransferFrom(bob, address(snr), 1, 1, "");
        assertEq(outputNft.ownerOf(2), bob);
        assertEq(outputNft.tokenURI(2), string.concat(BASE_URI, "/1"));

        (, , , , , , uint64 numRedeemed, uint64 nextUriIndex, ) = snr.settings();
        assertEq(numRedeemed, 2);
        assertEq(nextUriIndex, 2);
    }
}
