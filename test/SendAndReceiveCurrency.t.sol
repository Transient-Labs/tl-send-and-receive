// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {SendAndReceiveCurrency} from "src/SendAndReceiveCurrency.sol";
import {SendAndReceiveBase} from "src/lib/SendAndReceiveBase.sol";
import {
    OwnableUpgradeable, Initializable
} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import {ERC1155TL} from "tl-creator-contracts-3.7.0/erc-1155/ERC1155TL.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract ForceSend {
    constructor() payable {}

    function go(address payable to) external {
        selfdestruct(to);
    }
}

contract SendAndReceiveCurrencyTest is Test {
    SendAndReceiveCurrency public snrEth;
    SendAndReceiveCurrency public snrCoin;
    ERC1155TL public nft;
    MockERC20 public coin;

    address sink = address(0x5151);
    address bsy = address(0x42069);
    address bob = address(0xB0B);
    address ace = address(0xACE);

    receive() external payable {}

    function _setup_snrEth() internal {
        SendAndReceiveCurrency.Settings memory initSettings = SendAndReceiveCurrency.Settings({
            open: false,
            closed: true, // test :)
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: uint64(1),
            currencyAddress: address(0),
            valuePerRedemption: 100 ether, // test :)
            maxRedemptions: uint64(100),
            numRedeemed: uint64(10), // test :)
            openAt: uint64(block.timestamp), // test :)
            duration: uint64(365 days)
        });
        snrEth = new SendAndReceiveCurrency(false);
        snrEth.initialize(address(this), initSettings);
        assertEq(snrEth.owner(), address(this));
        (
            bool open,
            bool closed,
            address inputContractAddress,
            uint256 inputTokenId,
            uint64 inputAmount,
            address currencyAddress,
            uint256 valuePerRedemption,
            uint64 maxRedemptions,
            uint64 numRedeemed,
            uint64 openAt,
            uint64 duration
        ) = snrEth.settings();
        assertFalse(open);
        assertFalse(closed);
        assertEq(inputContractAddress, initSettings.inputContractAddress);
        assertEq(inputTokenId, initSettings.inputTokenId);
        assertEq(inputAmount, initSettings.inputAmount);
        assertEq(currencyAddress, address(0));
        assertEq(valuePerRedemption, 0);
        assertEq(maxRedemptions, initSettings.maxRedemptions);
        assertEq(numRedeemed, 0);
        assertEq(openAt, 0);
        assertEq(duration, initSettings.duration);
    }

    function _setup_snrCoin() internal {
        SendAndReceiveCurrency.Settings memory initSettings = SendAndReceiveCurrency.Settings({
            open: true, // test :)
            closed: false,
            inputContractAddress: address(nft),
            inputTokenId: 2,
            inputAmount: uint64(2),
            currencyAddress: address(coin),
            valuePerRedemption: 0,
            maxRedemptions: uint64(1000),
            numRedeemed: uint64(0),
            openAt: uint64(0), // test :)
            duration: uint64(3 days)
        });
        snrCoin = new SendAndReceiveCurrency(false);
        snrCoin.initialize(address(this), initSettings);
        assertEq(snrCoin.owner(), address(this));
        (
            bool open,
            bool closed,
            address inputContractAddress,
            uint256 inputTokenId,
            uint64 inputAmount,
            address currencyAddress,
            uint256 valuePerRedemption,
            uint64 maxRedemptions,
            uint64 numRedeemed,
            uint64 openAt,
            uint64 duration
        ) = snrCoin.settings();
        assertFalse(open);
        assertFalse(closed);
        assertEq(inputContractAddress, initSettings.inputContractAddress);
        assertEq(inputTokenId, initSettings.inputTokenId);
        assertEq(inputAmount, initSettings.inputAmount);
        assertEq(currencyAddress, address(coin));
        assertEq(valuePerRedemption, 0);
        assertEq(maxRedemptions, initSettings.maxRedemptions);
        assertEq(numRedeemed, 0);
        assertEq(openAt, 0);
        assertEq(duration, initSettings.duration);
    }

    function setUp() public {
        // setup ERC1155TL
        nft = new ERC1155TL(false);
        nft.initialize("Token", "TKN", "", address(this), 1000, address(this), new address[](0), true, address(0));
        address[] memory addys = new address[](3);
        addys[0] = bsy;
        addys[1] = bob;
        addys[2] = ace;
        uint256[] memory amts = new uint256[](3);
        amts[0] = type(uint64).max;
        amts[1] = type(uint64).max;
        amts[2] = type(uint64).max;
        nft.createToken("uri1", addys, amts);
        nft.createToken("uri2", addys, amts);
        nft.createToken("uri3", addys, amts);

        // setup coin
        coin = new MockERC20(address(this));

        // setup SNR ETH
        _setup_snrEth();

        // setup SNR Coin
        _setup_snrCoin();
    }

    function test_initialize_initializersDisabled() public {
        SendAndReceiveCurrency.Settings memory s = SendAndReceiveCurrency.Settings({
            open: false,
            closed: false,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: uint64(1),
            currencyAddress: address(0),
            valuePerRedemption: 0,
            maxRedemptions: uint64(100),
            numRedeemed: uint64(0),
            openAt: uint64(0),
            duration: uint64(365 days)
        });
        SendAndReceiveCurrency snr = new SendAndReceiveCurrency(true);
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        snr.initialize(address(this), s);
    }

    function test_initialize_errors() public {
        SendAndReceiveCurrency.Settings memory s = SendAndReceiveCurrency.Settings({
            open: false,
            closed: false,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: uint64(0),
            currencyAddress: address(0),
            valuePerRedemption: 0,
            maxRedemptions: uint64(100),
            numRedeemed: uint64(0),
            openAt: uint64(0),
            duration: uint64(365 days)
        });
        SendAndReceiveCurrency snr = new SendAndReceiveCurrency(false);

        // zero amount
        vm.expectRevert(SendAndReceiveCurrency.ZeroInputAmount.selector);
        snr.initialize(address(this), s);

        // zero redemptions
        s.inputAmount = uint64(1);
        s.maxRedemptions = uint64(0);
        vm.expectRevert(SendAndReceiveCurrency.ZeroRedemptions.selector);
        snr.initialize(address(this), s);

        // invalid input contract
        s.maxRedemptions = uint64(1);
        s.inputContractAddress = bsy;
        vm.expectRevert(SendAndReceiveCurrency.AddressZeroCodeLength.selector);
        snr.initialize(address(this), s);

        // currency address has no code
        s.inputContractAddress = address(nft);
        s.currencyAddress = bsy;
        vm.expectRevert(SendAndReceiveCurrency.AddressZeroCodeLength.selector);
        snr.initialize(address(this), s);

        // zero min duration
        s.currencyAddress = address(0);
        s.duration = uint64(0);
        vm.expectRevert(SendAndReceiveCurrency.ZeroDuration.selector);
        snr.initialize(address(this), s);
    }

    function test_accessControl(address hacker) public {
        vm.assume(hacker != address(this));

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snrEth.open();

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snrEth.close();

        vm.prank(hacker);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, hacker));
        snrEth.withdrawCurrency(address(coin), hacker, 100 ether);
    }

    function test_depositEth(address sender, uint256 amt) public {
        vm.assume(sender != address(this));
        vm.assume(sender != address(snrEth));
        amt = bound(amt, 100, 100 ether);

        vm.deal(address(this), amt + 1);
        vm.deal(address(sender), amt + 1);

        // allow deposit eth before open
        vm.expectEmit(true, true, false, false, address(snrEth));
        emit SendAndReceiveCurrency.EthDeposit(address(this), amt);
        snrEth.depositEth{value: amt}();

        vm.expectEmit(true, true, false, false, address(snrEth));
        emit SendAndReceiveCurrency.EthDeposit(address(sender), amt);
        vm.prank(sender);
        snrEth.depositEth{value: amt}();

        assertEq(address(snrEth).balance, amt * 2);

        // expect failure for erc-20
        vm.deal(address(this), amt);
        vm.expectRevert(SendAndReceiveCurrency.EthDepositNotAllowed.selector);
        snrCoin.depositEth{value: amt}();

        // expect failure if open
        snrEth.open();
        coin.transfer(address(snrCoin), 1000); // transfer to make sure the following call works
        snrCoin.open();
        vm.expectRevert(SendAndReceiveCurrency.EthDepositsClosed.selector);
        snrEth.depositEth{value: amt}();
        vm.expectRevert(SendAndReceiveCurrency.EthDepositNotAllowed.selector);
        snrCoin.depositEth{value: amt}();
    }

    function test_withdrawCurrency(uint256 amt) public {
        amt = bound(amt, 1000, 100 ether);

        vm.deal(address(this), amt);

        // deposit ETH and withdraw prior to open
        snrEth.depositEth{value: amt}();
        assertEq(address(snrEth).balance, amt);
        snrEth.withdrawCurrency(address(0), address(this), amt);
        assertEq(address(snrEth).balance, 0);

        // deposit ETH, open, and try to withdraw
        snrEth.depositEth{value: amt}();
        assertEq(address(snrEth).balance, amt);
        snrEth.open();
        vm.expectRevert(SendAndReceiveCurrency.RedemptionOpen.selector);
        snrEth.withdrawCurrency(address(0), address(this), amt);

        // after open, withdraw another currency
        coin.transfer(address(snrEth), amt);
        assertEq(coin.balanceOf(address(snrEth)), amt);
        snrEth.withdrawCurrency(address(coin), address(this), amt);
        assertEq(coin.balanceOf(address(snrEth)), 0);

        // deposit ERC-20 and withdraw prior to open
        coin.transfer(address(snrCoin), amt);
        assertEq(coin.balanceOf(address(snrCoin)), amt);
        snrCoin.withdrawCurrency(address(coin), address(this), amt);
        assertEq(coin.balanceOf(address(snrCoin)), 0);

        // deposit ERC-20, open, and try to withdraw
        coin.transfer(address(snrCoin), amt);
        assertEq(coin.balanceOf(address(snrCoin)), amt);
        snrCoin.open();
        vm.expectRevert(SendAndReceiveCurrency.RedemptionOpen.selector);
        snrCoin.withdrawCurrency(address(coin), address(this), amt);

        // after open, withdraw another currency
        vm.deal(address(snrCoin), amt);
        assertEq(address(snrCoin).balance, amt);
        snrCoin.withdrawCurrency(address(0), address(this), amt);
        assertEq(address(snrCoin).balance, 0);
    }

    function test_singleTransfer_eth_errors() public {
        // deposit ETH
        vm.deal(address(this), 1 ether);
        snrEth.depositEth{value: 1 ether}();

        // try redeeming before open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snrEth), 1, 1, "");

        // open redemption
        snrEth.open();

        // try opening again
        vm.expectRevert(SendAndReceiveCurrency.AlreadyConfigured.selector);
        snrEth.open();

        // invalid contract address (simulate by sending call directly)
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        snrEth.onERC1155Received(address(0), bsy, 1, 1, "");

        // invalid token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        nft.safeTransferFrom(bsy, address(snrEth), 2, 1, "");

        // invalid amount
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidAmountSent.selector);
        nft.safeTransferFrom(bsy, address(snrEth), 1, 2, "");

        // close
        vm.warp(block.timestamp + 366 days);
        snrEth.close();
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        nft.safeTransferFrom(bsy, address(snrEth), 1, 1, "");
    }

    function test_singleTransfer_erc20_errors() public {
        // deposit ERC-20
        coin.transfer(address(snrCoin), 1 ether);

        // try redeeming before open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.NotOpen.selector);
        nft.safeTransferFrom(bsy, address(snrCoin), 1, 1, "");

        // open redemption
        snrCoin.open();

        // try opening again
        vm.expectRevert(SendAndReceiveCurrency.AlreadyConfigured.selector);
        snrCoin.open();

        // invalid contract address (simulate by sending call directly)
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        snrCoin.onERC1155Received(address(0), bsy, 1, 1, "");

        // invalid token
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        nft.safeTransferFrom(bsy, address(snrCoin), 1, 1, "");

        // invalid amount
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidAmountSent.selector);
        nft.safeTransferFrom(bsy, address(snrCoin), 2, 1, "");

        // close
        vm.warp(block.timestamp + 4 days);
        snrCoin.close();
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        nft.safeTransferFrom(bsy, address(snrCoin), 2, 2, "");
    }

    function test_singleTransfer_eth(uint256 amt) public {
        amt = bound(amt, 100, 100 ether);

        // deposit ETH
        vm.deal(address(this), amt + 1);
        snrEth.depositEth{value: amt}();

        // open redemption
        snrEth.open();
        (bool open,,,,,, uint256 valuePerRedemption, uint64 maxRedemptions, uint64 numRedeemed, uint64 openAt,) = snrEth.settings();
        uint256 calcValuePerRedemption = amt / uint256(maxRedemptions);
        assertTrue(open);
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);
        assertEq(openAt, uint64(block.timestamp));

        // force eth to contract and ensure that it doesn't mess with anything
        vm.deal(address(this), 1 ether);
        ForceSend fs = new ForceSend{value: 1 ether}();
        fs.go(payable(address(snrEth)));
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);

        // get initial balances
        uint256 snrInitBalance = address(snrEth).balance;

        // bsy redeems 50
        for (uint256 i = 1; i <= 50; i++) {
            vm.prank(bsy);
            vm.expectEmit(true, true, false, false);
            emit SendAndReceiveBase.Redeemed(bsy, 1);
            nft.safeTransferFrom(bsy, address(snrEth), 1, 1, "");
            (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
            assertEq(valuePerRedemption, calcValuePerRedemption);
            assertEq(numRedeemed, i);
            assertEq(address(snrEth).balance, snrInitBalance - calcValuePerRedemption * i);
            assertEq(bsy.balance, calcValuePerRedemption * i);
        }

        assertEq(nft.balanceOf(address(0xdead), 1), 50);

        // bob redeems 49
        for (uint256 i = 51; i <= 99; i++) {
            vm.prank(bob);
            vm.expectEmit(true, true, false, false);
            emit SendAndReceiveBase.Redeemed(bob, 1);
            nft.safeTransferFrom(bob, address(snrEth), 1, 1, "");
            (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
            assertEq(valuePerRedemption, calcValuePerRedemption);
            assertEq(numRedeemed, i);
            assertEq(address(snrEth).balance, snrInitBalance - calcValuePerRedemption * i);
            assertEq(bob.balance, calcValuePerRedemption * (i - 50));
        }

        assertEq(nft.balanceOf(address(0xdead), 1), 99);

        // ace redeems 1
        vm.prank(ace);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(ace, 1);
        nft.safeTransferFrom(ace, address(snrEth), 1, 1, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 100);
        assertEq(address(snrEth).balance, snrInitBalance - calcValuePerRedemption * 100);
        assertEq(ace.balance, calcValuePerRedemption);

        assertEq(nft.balanceOf(address(0xdead), 1), 100);

        // ace tries to redeem another after it's done
        vm.prank(ace);
        vm.expectRevert(SendAndReceiveCurrency.NoSupplyLeft.selector);
        nft.safeTransferFrom(ace, address(snrEth), 1, 1, "");

        // after cap, withdraw eth
        snrEth.withdrawCurrency(address(0), sink, 1 ether);
        assertLt(address(snrEth).balance, 1000); // less than 1000 wei should be left over as dust
        assertEq(sink.balance, 1 ether);
    }

    function test_singleTransfer_erc20(uint256 amt) public {
        amt = bound(amt, 1000, 100 ether);

        // deposit ERC-20
        coin.transfer(address(snrCoin), amt);

        // open redemption
        snrCoin.open();
        (bool open,,,,,, uint256 valuePerRedemption, uint64 maxRedemptions, uint64 numRedeemed, uint64 openAt,) = snrCoin.settings();
        uint256 calcValuePerRedemption = amt / uint256(maxRedemptions);
        assertTrue(open);
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);
        assertEq(openAt, uint64(block.timestamp));

        // force coin to contract and ensure that it doesn't mess with anything
        coin.transfer(address(snrCoin), 1 ether);
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);

        // get initial balances
        uint256 snrInitBalance = coin.balanceOf(address(snrCoin));

        // bsy redeems 50
        for (uint256 i = 1; i <= 50; i++) {
            vm.prank(bsy);
            vm.expectEmit(true, true, false, false);
            emit SendAndReceiveBase.Redeemed(bsy, 1);
            nft.safeTransferFrom(bsy, address(snrCoin), 2, 2, "");
            (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
            assertEq(valuePerRedemption, calcValuePerRedemption);
            assertEq(numRedeemed, i);
            assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * i);
            assertEq(coin.balanceOf(bsy), calcValuePerRedemption * i);
        }

        assertEq(nft.balanceOf(address(0xdead), 2), 100);

        // bob redeems 49
        for (uint256 i = 51; i <= 99; i++) {
            vm.prank(bob);
            vm.expectEmit(true, true, false, false);
            emit SendAndReceiveBase.Redeemed(bob, 1);
            nft.safeTransferFrom(bob, address(snrCoin), 2, 2, "");
            (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
            assertEq(valuePerRedemption, calcValuePerRedemption);
            assertEq(numRedeemed, i);
            assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * i);
            assertEq(coin.balanceOf(bob), calcValuePerRedemption * (i - 50));
        }

        assertEq(nft.balanceOf(address(0xdead), 2), 198);

        // ace redeems 1
        vm.prank(ace);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(ace, 1);
        nft.safeTransferFrom(ace, address(snrCoin), 2, 2, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 100);
        assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * 100);
        assertEq(coin.balanceOf(ace), calcValuePerRedemption);

        assertEq(nft.balanceOf(address(0xdead), 2), 200);

        // bsy gets the rest
        for (uint256 i = 101; i <= 1000; i++) {
            vm.prank(bsy);
            vm.expectEmit(true, true, false, false);
            emit SendAndReceiveBase.Redeemed(bsy, 1);
            nft.safeTransferFrom(bsy, address(snrCoin), 2, 2, "");
            (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
            assertEq(valuePerRedemption, calcValuePerRedemption);
            assertEq(numRedeemed, i);
            assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * i);
            assertEq(coin.balanceOf(bsy), calcValuePerRedemption * (i - 50));
        }

        assertEq(nft.balanceOf(address(0xdead), 2), 2000);

        // ace tries to redeem another after it's done
        vm.prank(ace);
        vm.expectRevert(SendAndReceiveCurrency.NoSupplyLeft.selector);
        nft.safeTransferFrom(ace, address(snrCoin), 2, 2, "");

        // after cap, withdraw coin
        snrCoin.withdrawCurrency(address(coin), sink, 1 ether);
        assertLt(coin.balanceOf(address(snrCoin)), 1000); // less than 1000 wei of dust should be left over
        assertEq(coin.balanceOf(sink), 1 ether);
    }

    function test_batchTransfer_eth_errors() public {
        // deposit ETH
        vm.deal(address(this), 1 ether);
        snrEth.depositEth{value: 1 ether}();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 1;

        // try redeeming before open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");

        // open redemption
        snrEth.open();

        // try opening again
        vm.expectRevert(SendAndReceiveCurrency.AlreadyConfigured.selector);
        snrEth.open();

        // invalid contract address (simulate by sending call directly)
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        snrEth.onERC1155BatchReceived(address(0), bsy, ids, values, "");

        // invalid token
        ids[0] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");

        ids[0] = 1;
        ids[1] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");

        // invalid amount
        ids[1] = 1;
        values[0] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");

        values[0] = 1;
        values[1] = 2;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");

        // close
        values[1] = 1;
        vm.warp(block.timestamp + 366 days);
        snrEth.close();
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");
    }

    function test_batchTransfer_erc20_errors() public {
        // deposit ERC-20
        coin.transfer(address(snrCoin), 1 ether);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 2;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 2;
        values[1] = 2;

        // try redeeming before open
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.NotOpen.selector);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");

        // open redemption
        snrCoin.open();

        // try opening again
        vm.expectRevert(SendAndReceiveCurrency.AlreadyConfigured.selector);
        snrCoin.open();

        // invalid contract address (simulate by sending call directly)
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        snrCoin.onERC1155BatchReceived(address(0), bsy, ids, values, "");

        // invalid token
        ids[0] = 1;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");

        ids[0] = 2;
        ids[1] = 1;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidInputToken.selector);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");

        // invalid amount
        ids[1] = 2;
        values[0] = 1;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");

        values[0] = 2;
        values[1] = 1;
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.InvalidAmountSent.selector);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");

        // close
        values[1] = 2;
        vm.warp(block.timestamp + 4 days);
        snrCoin.close();
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");
    }

    function test_batchTransfer_eth(uint256 amt) public {
        amt = bound(amt, 100, 100 ether);

        // deposit ETH
        vm.deal(address(this), amt + 1);
        snrEth.depositEth{value: amt}();

        // open redemption
        snrEth.open();
        (bool open,,,,,, uint256 valuePerRedemption, uint64 maxRedemptions, uint64 numRedeemed, uint64 openAt,) = snrEth.settings();
        uint256 calcValuePerRedemption = amt / uint256(maxRedemptions);
        assertTrue(open);
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);
        assertEq(openAt, uint64(block.timestamp));

        // force eth to contract and ensure that it doesn't mess with anything
        vm.deal(address(this), 1 ether);
        ForceSend fs = new ForceSend{value: 1 ether}();
        fs.go(payable(address(snrEth)));
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);

        // get initial balances
        uint256 snrInitBalance = address(snrEth).balance;

        // variables
        uint256[] memory ids = new uint256[](50);
        uint256[] memory values = new uint256[](50);

        // bsy redeems 50
        for (uint256 i = 0; i < 50; i++) {
            ids[i] = 1;
            values[i] = 1;
        }
        vm.prank(bsy);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(bsy, 50);
        nft.safeBatchTransferFrom(bsy, address(snrEth), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 50);
        assertEq(address(snrEth).balance, snrInitBalance - calcValuePerRedemption * 50);
        assertEq(bsy.balance, calcValuePerRedemption * 50);

        assertEq(nft.balanceOf(address(0xdead), 1), 50);

        // bob redeems 49
        ids = new uint256[](49);
        values = new uint256[](49);
        for (uint256 i = 0; i < 49; i++) {
            ids[i] = 1;
            values[i] = 1;
        }
        vm.prank(bob);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(bob, 49);
        nft.safeBatchTransferFrom(bob, address(snrEth), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 99);
        assertEq(address(snrEth).balance, snrInitBalance - calcValuePerRedemption * 99);
        assertEq(bob.balance, calcValuePerRedemption * 49);

        assertEq(nft.balanceOf(address(0xdead), 1), 99);

        // ace redeems 1
        ids = new uint256[](1);
        ids[0] = 1;
        values = new uint256[](1);
        values[0] = 1;
        vm.prank(ace);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(ace, 1);
        nft.safeBatchTransferFrom(ace, address(snrEth), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrEth.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 100);
        assertEq(address(snrEth).balance, snrInitBalance - calcValuePerRedemption * 100);
        assertEq(ace.balance, calcValuePerRedemption);

        assertEq(nft.balanceOf(address(0xdead), 1), 100);

        // ace tries to redeem another after it's done
        vm.prank(ace);
        vm.expectRevert(SendAndReceiveCurrency.NoSupplyLeft.selector);
        nft.safeBatchTransferFrom(ace, address(snrEth), ids, values, "");

        // after cap, withdraw eth
        snrEth.withdrawCurrency(address(0), sink, 1 ether);
        assertLt(address(snrEth).balance, 1000); // less than 1000 wei should be left over
        assertEq(sink.balance, 1 ether);
    }

    function test_batchTransfer_erc20(uint256 amt) public {
        amt = bound(amt, 1000, 100 ether);

        // deposit ERC-20
        coin.transfer(address(snrCoin), amt);

        // open redemption
        snrCoin.open();
        (bool open,,,,,, uint256 valuePerRedemption, uint64 maxRedemptions, uint64 numRedeemed, uint64 openAt,) = snrCoin.settings();
        uint256 calcValuePerRedemption = amt / uint256(maxRedemptions);
        assertTrue(open);
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);
        assertEq(openAt, uint64(block.timestamp));

        // force eth to contract and ensure that it doesn't mess with anything
        coin.transfer(address(snrCoin), 1 ether);
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 0);

        // get initial balances
        uint256 snrInitBalance = coin.balanceOf(address(snrCoin));

        // variables
        uint256[] memory ids = new uint256[](50);
        uint256[] memory values = new uint256[](50);

        // bsy redeems 50
        for (uint256 i = 0; i < 50; i++) {
            ids[i] = 2;
            values[i] = 2;
        }
        vm.prank(bsy);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(bsy, 50);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 50);
        assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * 50);
        assertEq(coin.balanceOf(bsy), calcValuePerRedemption * 50);

        assertEq(nft.balanceOf(address(0xdead), 2), 100);

        // bob redeems 49
        ids = new uint256[](49);
        values = new uint256[](49);
        for (uint256 i = 0; i < 49; i++) {
            ids[i] = 2;
            values[i] = 2;
        }
        vm.prank(bob);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(bob, 49);
        nft.safeBatchTransferFrom(bob, address(snrCoin), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 99);
        assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * 99);
        assertEq(coin.balanceOf(bob), calcValuePerRedemption * 49);

        assertEq(nft.balanceOf(address(0xdead), 2), 198);

        // ace redeems 1
        ids = new uint256[](1);
        ids[0] = 2;
        values = new uint256[](1);
        values[0] = 2;
        vm.prank(ace);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(ace, 1);
        nft.safeBatchTransferFrom(ace, address(snrCoin), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 100);
        assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * 100);
        assertEq(coin.balanceOf(ace), calcValuePerRedemption);

        assertEq(nft.balanceOf(address(0xdead), 2), 200);

        // bsy gets the rest
        ids = new uint256[](900);
        values = new uint256[](900);
        for (uint256 i = 0; i < 900; i++) {
            ids[i] = 2;
            values[i] = 2;
        }
        vm.prank(bsy);
        vm.expectEmit(true, true, false, false);
        emit SendAndReceiveBase.Redeemed(bsy, 900);
        nft.safeBatchTransferFrom(bsy, address(snrCoin), ids, values, "");
        (,,,,,, valuePerRedemption, maxRedemptions, numRedeemed,,) = snrCoin.settings();
        assertEq(valuePerRedemption, calcValuePerRedemption);
        assertEq(numRedeemed, 1000);
        assertEq(coin.balanceOf(address(snrCoin)), snrInitBalance - calcValuePerRedemption * 1000);
        assertEq(coin.balanceOf(bsy), calcValuePerRedemption * 950);

        assertEq(nft.balanceOf(address(0xdead), 2), 2000);

        // ace tries to redeem another after it's done
        vm.prank(ace);
        vm.expectRevert(SendAndReceiveCurrency.NoSupplyLeft.selector);
        nft.safeBatchTransferFrom(ace, address(snrCoin), ids, values, "");

        // after cap, withdraw coin
        snrCoin.withdrawCurrency(address(coin), sink, 1 ether);
        assertLt(coin.balanceOf(address(snrCoin)), 1000); // less than 100 wei of dust
        assertEq(coin.balanceOf(sink), 1 ether);
    }

    function test_open_notEnoughvalue() public {
        vm.expectRevert(SendAndReceiveCurrency.ZeroValuePerRedemption.selector);
        snrEth.open();

        vm.expectRevert(SendAndReceiveCurrency.ZeroValuePerRedemption.selector);
        snrCoin.open();
    }

    function test_closed_eth() public {
        // deposit eth
        vm.deal(address(this), 1 ether);
        snrEth.depositEth{value: 1 ether}();

        // try to close before open
        vm.expectRevert(SendAndReceiveCurrency.NotOpen.selector);
        snrEth.close();

        // open
        snrEth.open();

        // redeem a few
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snrEth), 1, 1, "");
        vm.prank(bob);
        nft.safeTransferFrom(bob, address(snrEth), 1, 1, "");
        vm.prank(ace);
        nft.safeTransferFrom(ace, address(snrEth), 1, 1, "");

        // try to close before time is up
        vm.expectRevert(SendAndReceiveCurrency.CannotClose.selector);
        snrEth.close();

        // close
        vm.warp(block.timestamp + 366 days);
        snrEth.close();

        // try to redeem
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        nft.safeTransferFrom(bsy, address(snrEth), 1, 1, "");

        // try to open again
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        snrEth.open();

        // withdraw currency
        assertEq(address(this).balance, 0);
        snrEth.withdrawCurrency(address(0), address(this), address(snrEth).balance);
        assertLt(address(this).balance, 1 ether);
        assertGt(address(this).balance, 0);
    }

    function test_closed_erc20() public {
        // deposit coin
        coin.transfer(address(snrCoin), 1 ether);

        // try to close before open
        vm.expectRevert(SendAndReceiveCurrency.NotOpen.selector);
        snrCoin.close();

        // open
        snrCoin.open();

        // redeem a few
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snrCoin), 2, 2, "");
        vm.prank(bob);
        nft.safeTransferFrom(bob, address(snrCoin), 2, 2, "");
        vm.prank(ace);
        nft.safeTransferFrom(ace, address(snrCoin), 2, 2, "");

        // try to close before time is up
        vm.expectRevert(SendAndReceiveCurrency.CannotClose.selector);
        snrCoin.close();

        // close
        vm.warp(block.timestamp + 4 days);
        snrCoin.close();

        // try to redeem
        vm.prank(bsy);
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        nft.safeTransferFrom(bsy, address(snrCoin), 2, 2, "");

        // try to open again
        vm.expectRevert(SendAndReceiveCurrency.Closed.selector);
        snrCoin.open();

        // withdraw currency
        assertEq(coin.balanceOf(sink), 0);
        snrCoin.withdrawCurrency(address(coin), address(sink), coin.balanceOf(address(snrCoin)));
        assertLt(coin.balanceOf(sink), 1 ether);
        assertGt(coin.balanceOf(sink), 0);
    }
}
