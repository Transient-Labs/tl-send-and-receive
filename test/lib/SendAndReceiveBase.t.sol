// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {MockSendAndReceive, SendAndReceiveBase} from "../mocks/MockSendAndReceive.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {ERC1155TL} from "tl-creator-contracts-3.7.0/erc-1155/ERC1155TL.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";

contract SendAndReceiveBaseTest is Test {
    MockSendAndReceive public snr;
    ERC1155TL public nft;
    MockERC20 public coin;
    MockERC721 public erc721;

    address bsy = address(0x42069);

    function setUp() public {
        // setup ERC1155TL
        nft = new ERC1155TL(false);
        nft.initialize("Token", "TKN", "", address(this), 1000, address(this), new address[](0), true, address(0));
        address[] memory addys = new address[](1);
        addys[0] = bsy;
        uint256[] memory amts = new uint256[](1);
        amts[0] = 100;
        nft.createToken("uri1", addys, amts);
        nft.createToken("uri2", addys, amts);
        nft.createToken("uri3", addys, amts);

        // setup SNR
        snr = new MockSendAndReceive(false);
        snr.initialize(address(this));
        assertEq(snr.owner(), address(this));

        // setup coin
        coin = new MockERC20(address(this));

        // setup erc721
        erc721 = new MockERC721(bsy);
    }

    function test_onERC1155Received(address sender, uint16 amt) public {
        vm.assume(sender.code.length == 0);
        vm.assume(sender != address(0));
        vm.assume(amt > 0);

        // mint tokens to sender
        address[] memory addresses = new address[](1);
        addresses[0] = sender;
        uint256[] memory amts = new uint256[](1);
        amts[0] = uint256(amt);
        nft.mintToken(1, addresses, amts);

        // try minting to the S&R
        addresses[0] = address(snr);
        vm.expectRevert(SendAndReceiveBase.FromZeroAddress.selector);
        nft.mintToken(1, addresses, amts);

        // try sending zero amount
        vm.startPrank(sender);
        vm.expectRevert(SendAndReceiveBase.ZeroAmountSent.selector);
        nft.safeTransferFrom(sender, address(snr), 1, 0, "");

        // send amount
        vm.expectEmit();
        emit MockSendAndReceive.Processing();
        vm.expectEmit();
        emit MockSendAndReceive.Sinking();
        vm.expectEmit();
        emit MockSendAndReceive.Redeeming();
        nft.safeTransferFrom(sender, address(snr), 1, amt, "");
        vm.stopPrank();

        // check results
        assertEq(nft.balanceOf(address(snr), 1), amt);
    }

    function test_onERC1155BatchReceived(address sender, uint16 amt1, uint16 amt2, uint16 amt3) public {
        vm.assume(sender.code.length == 0);
        vm.assume(sender != address(0));
        vm.assume(amt1 > 0 && amt2 > 0 && amt3 > 0);

        // mint tokens to sender
        address[] memory addresses = new address[](1);
        addresses[0] = sender;
        uint256[] memory amts = new uint256[](1);
        amts[0] = uint256(amt1);
        nft.mintToken(1, addresses, amts);
        amts[0] = uint256(amt2);
        nft.mintToken(2, addresses, amts);
        amts[0] = uint256(amt3);
        nft.mintToken(3, addresses, amts);

        // try minting to the S&R
        addresses[0] = address(snr);
        vm.expectRevert(SendAndReceiveBase.FromZeroAddress.selector);
        snr.onERC1155BatchReceived(address(0), address(0), amts, amts, "");

        // try forcing array length mismatch
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        vm.expectRevert(SendAndReceiveBase.ArrayLengthMismatch.selector);
        snr.onERC1155BatchReceived(address(0), sender, ids, amts, "");

        // try sending zero amount
        uint256[] memory values = new uint256[](3);
        values[0] = uint256(amt1);
        values[1] = uint256(amt2);
        values[2] = uint256(amt3);
        vm.startPrank(sender);
        values[0] = 0;
        vm.expectRevert(SendAndReceiveBase.ZeroAmountSent.selector);
        nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
        values[0] = uint256(amt1);
        values[1] = 0;
        vm.expectRevert(SendAndReceiveBase.ZeroAmountSent.selector);
        nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
        values[1] = uint256(amt2);
        values[2] = 0;
        vm.expectRevert(SendAndReceiveBase.ZeroAmountSent.selector);
        nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");

        // send amount
        values[2] = uint256(amt3);
        vm.expectEmit();
        emit MockSendAndReceive.Processing();
        vm.expectEmit();
        emit MockSendAndReceive.Processing();
        vm.expectEmit();
        emit MockSendAndReceive.Processing();
        vm.expectEmit();
        emit MockSendAndReceive.Sinking();
        vm.expectEmit();
        emit MockSendAndReceive.Redeeming();
        nft.safeBatchTransferFrom(sender, address(snr), ids, values, "");
        vm.stopPrank();

        // check results
        assertEq(nft.balanceOf(address(snr), 1), amt1);
        assertEq(nft.balanceOf(address(snr), 2), amt2);
        assertEq(nft.balanceOf(address(snr), 3), amt3);
    }

    function test_access_control(address hacker) public {
        vm.assume(hacker != address(this));

        vm.startPrank(hacker);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.withdrawCurrency(address(coin), hacker, 100);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.withdrawCurrency(address(0), hacker, 100);

        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snr.withdrawERC721(address(coin), hacker, 1);

        vm.stopPrank();
    }

    function test_withdrawCurrency(uint256 amt) public {
        amt = bound(amt, 1, 100 ether);

        // test eth
        vm.deal(address(this), amt);
        payable(address(snr)).call{value: amt}("");
        assertEq(address(snr).balance, amt, "SNR didn't receive eth");
        vm.expectRevert(SendAndReceiveBase.CannotSendToZeroAddress.selector);
        snr.withdrawCurrency(address(0), address(0), amt);
        snr.withdrawCurrency(address(0), bsy, amt);
        assertEq(address(snr).balance, 0, "SNR eth balance didn't clear");
        assertEq(bsy.balance, amt, "bsy didn't get the eth");

        // test coin
        coin.transfer(address(snr), amt);
        assertEq(coin.balanceOf(address(snr)), amt, "SNR didn't receive coin");
        vm.expectRevert(SendAndReceiveBase.CannotSendToZeroAddress.selector);
        snr.withdrawCurrency(address(coin), address(0), amt);
        snr.withdrawCurrency(address(coin), bsy, amt);
        assertEq(coin.balanceOf(address(snr)), 0, "SNR coin balance didn't clear");
        assertEq(coin.balanceOf(bsy), amt, "bsy didn't get the coin");
    }

    function test_withdrawERC721() public {
        vm.prank(bsy);
        erc721.transferFrom(bsy, address(snr), 1);

        assertEq(erc721.ownerOf(1), address(snr), "snr doesn't own 721");
        snr.withdrawERC721(address(erc721), bsy, 1);
        assertEq(erc721.ownerOf(1), bsy, "bsy doesn't own 721");
    }

    function test_supportsInterface() public view {
        assertTrue(snr.supportsInterface(0x01ffc9a7), "ERC-165 failure"); // ERC-165
        assertTrue(snr.supportsInterface(0x4e2312e0), "ERC-1155 Receiver failure"); // ERC-1155 Receiver
    }
}
