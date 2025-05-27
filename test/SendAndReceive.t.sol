// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.22;

import "forge-std-1.9.7/Test.sol";
import { ISendAndReceive } from "./ISendAndReceive.sol";
import { ERC1155TL } from "tl-creator-contracts-3.3.1/erc-1155/ERC1155TL.sol";

contract SendAndReceiveTest is Test {
    ISendAndReceive public snr;
    ERC1155TL public nft;

    address bsy = address(0x42069);
    address bob = address(0xB0B);
    address ace = address(0xACE);

    uint256 amt = 100;

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
        ISendAndReceive.InitConfig memory initConfig = ISendAndReceive.InitConfig({
            contract_address: address(nft),
            token_id: 4,
            open_at: 0,
            max_supply: type(uint256).max
        });
        snr = ISendAndReceive(deployCode("send_and_receive_editions", abi.encode(initConfig)));
        assertEq(snr.owner(), address(this));
        assertEq(snr.contract_address(), address(nft));
        assertEq(snr.token_id(), 4);
        assertEq(snr.open_at(), 0);
        assertEq(snr.max_supply(), type(uint256).max);

        ISendAndReceive.InputConfig[] memory configs = new ISendAndReceive.InputConfig[](2);
        configs[0] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 1,
            amount: 1
        });
        configs[1] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 2,
            amount: 2
        });

        snr.config_inputs(configs);

        assertEq(snr.get_input_config(address(nft), 1), 1);
        assertEq(snr.get_input_config(address(nft), 2), 2);
        assertEq(snr.get_input_config(address(nft), 3), 0);

        // set mint contract
        address[] memory mintContracts = new address[](1);
        mintContracts[0] = address(snr);
        nft.setApprovedMintContracts(mintContracts, true);
    }

    function test_access_control(address hacker) public {
        vm.assume(hacker != address(this));

        ISendAndReceive.InputConfig[] memory configs = new ISendAndReceive.InputConfig[](1);
        configs[0] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 1,
            amount: 1
        });

        ISendAndReceive.SettingsConfig memory settingsConfig = ISendAndReceive.SettingsConfig({
            open_at: 0,
            max_supply: type(uint256).max
        });

        vm.prank(hacker);
        vm.expectRevert("ownable: caller is not the owner");
        snr.config_inputs(configs);

        vm.prank(hacker);
        vm.expectRevert("ownable: caller is not the owner");
        snr.withdraw_nfts(address(nft), new uint256[](0), new uint256[](0), hacker);

        vm.prank(hacker);
        vm.expectRevert("ownable: caller is not the owner");
        snr.set_paused(true);

        vm.prank(hacker);
        vm.expectRevert("ownable: caller is not the owner");
        snr.config_settings(settingsConfig);
    }

    function test_safeTransferFrom_failures() public {
        ISendAndReceive.SettingsConfig memory config = ISendAndReceive.SettingsConfig({
            open_at: block.timestamp + 10,
            max_supply: type(uint256).max
        });
        // redemption not open
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: redemption not open");
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.stopPrank();

        // no supply
        config.open_at = 0;
        config.max_supply = 0;
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: no supply remaining");
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.stopPrank();

        // invalid token
        config.open_at = 0;
        config.max_supply = type(uint256).max;
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid input token");
        nft.safeTransferFrom(bsy, address(snr), 3, 1, "");
        vm.stopPrank();

        // invalid token with 0 amount
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid input token");
        nft.safeTransferFrom(bsy, address(snr), 3, 0, "");
        vm.stopPrank();

        // invalid amount
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid amount of token sent");
        nft.safeTransferFrom(bsy, address(snr), 1, 2, "");
        vm.stopPrank(); 

        // invalid amount with 0 amount
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid amount of token sent");
        nft.safeTransferFrom(bsy, address(snr), 1, 0, "");
        vm.stopPrank(); 
    }

    function test_safeTransferFrom() public {
        // BSY transfers 1 of token 1 and token 2
        vm.startPrank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        nft.safeTransferFrom(bsy, address(snr), 2, 2, "");
        assertEq(nft.balanceOf(bsy, 1), amt - 1);
        assertEq(nft.balanceOf(bsy, 2), amt - 2);
        assertEq(nft.balanceOf(bsy, 4), 2);
        vm.stopPrank();

        // BSY transfers 1 of token 1 and token 2, again
        vm.startPrank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        nft.safeTransferFrom(bsy, address(snr), 2, 2, "");
        assertEq(nft.balanceOf(bsy, 1), amt - 2);
        assertEq(nft.balanceOf(bsy, 2), amt - 4);
        assertEq(nft.balanceOf(bsy, 4), 4);
        vm.stopPrank();

        // Bob transfers
        vm.startPrank(bob);
        nft.safeTransferFrom(bob, address(snr), 1, 1, "");
        nft.safeTransferFrom(bob, address(snr), 2, 2, "");
        assertEq(nft.balanceOf(bob, 1), amt - 1);
        assertEq(nft.balanceOf(bob, 2), amt - 2);
        assertEq(nft.balanceOf(bob, 4), 2);
        vm.stopPrank();
        
        // Ace transfers
        vm.startPrank(ace);
        nft.safeTransferFrom(ace, address(snr), 1, 1, "");
        nft.safeTransferFrom(ace, address(snr), 2, 2, "");
        assertEq(nft.balanceOf(ace, 1), amt - 1);
        assertEq(nft.balanceOf(ace, 2), amt - 2);
        assertEq(nft.balanceOf(ace, 4), 2);
        vm.stopPrank();
        

        // Withdraw nfts
        uint256 tokenOneAmt = 4;
        uint256 tokenTwoAmt = 8;
        assertEq(nft.balanceOf(address(snr), 1), tokenOneAmt);
        assertEq(nft.balanceOf(address(snr), 2), tokenTwoAmt);
        assertEq(nft.balanceOf(address(snr), 3), 0);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = tokenOneAmt;
        values[1] = tokenTwoAmt;
        snr.withdraw_nfts(address(nft), tokenIds, values, address(0xdead));
        assertEq(nft.balanceOf(address(snr), 1), 0);
        assertEq(nft.balanceOf(address(snr), 2), 0);
        assertEq(nft.balanceOf(address(snr), 3), 0);
        assertEq(nft.balanceOf(address(0xdead), 1), tokenOneAmt);
        assertEq(nft.balanceOf(address(0xdead), 2), tokenTwoAmt);
        assertEq(nft.balanceOf(address(0xdead), 3), 0);
        assertEq(snr.num_redeemed(), 8);
    }

    function test_safeTransferFrom_fuzz(uint256 amountOne, uint256 amountTwo) public {
        vm.assume(amountOne > 0 && amountTwo > 0);
        if (amountOne > amt) {
            amountOne = amountOne % amt + 1;
        }
        if (amountTwo > amt) {
            amountTwo = amountTwo % amt + 1;
        }

        ISendAndReceive.InputConfig[] memory configs = new ISendAndReceive.InputConfig[](2);
        configs[0] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 1,
            amount: amountOne
        });
        configs[1] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 2,
            amount: amountTwo
        });

        snr.config_inputs(configs);

        // BSY transfers 1 of token 1 and token 2
        vm.startPrank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, amountOne, "");
        nft.safeTransferFrom(bsy, address(snr), 2, amountTwo, "");
        assertEq(nft.balanceOf(bsy, 1), amt - amountOne);
        assertEq(nft.balanceOf(bsy, 2), amt - amountTwo);
        assertEq(nft.balanceOf(bsy, 4), 2);
        assertEq(snr.num_redeemed(), 2);
        assertEq(nft.balanceOf(address(snr), 1), amountOne);
        assertEq(nft.balanceOf(address(snr), 2), amountTwo);
        vm.stopPrank();

        // withdraw nfts
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory values = new uint256[](2);
        values[0] = amountOne;
        values[1] = amountTwo;
        snr.withdraw_nfts(address(nft), tokenIds, values, address(0xdead));
        assertEq(nft.balanceOf(address(snr), 1), 0);
        assertEq(nft.balanceOf(address(snr), 2), 0);
        assertEq(nft.balanceOf(address(0xdead), 1), amountOne);
        assertEq(nft.balanceOf(address(0xdead), 2), amountTwo);
    }

    function test_safeBatchTransferFrom_failures() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        ISendAndReceive.SettingsConfig memory config = ISendAndReceive.SettingsConfig({
            open_at: block.timestamp + 10,
            max_supply: type(uint256).max
        });

        // redemption not open
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: redemption not open");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // no supply
        config.open_at = 0;
        config.max_supply = 0;
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: no supply remaining");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // no supply mid tx
        config.open_at = 0;
        config.max_supply = 1;
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: no supply remaining");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // invalid token
        config.open_at = 0;
        config.max_supply = type(uint256).max;
        tokenIds[1] = 3;
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid input token");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // invalid token with 0 amount
        config.open_at = 0;
        config.max_supply = type(uint256).max;
        tokenIds[1] = 3;
        values[1] = 0;
        snr.config_settings(config);
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid input token");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // invalid amount
        tokenIds[1] = 2;
        values[1] = 1;
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid amount of token sent");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // invalid amount with 0 amount
        tokenIds[1] = 2;
        values[1] = 0;
        vm.startPrank(bsy);
        vm.expectRevert("send_and_receive_editions: invalid amount of token sent");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();
    }

    function test_safeBatchTransferFrom() public {

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        // BSY transfers 1 of token 1 and token 2
        vm.startPrank(bsy);
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        assertEq(nft.balanceOf(bsy, 1), amt - 1);
        assertEq(nft.balanceOf(bsy, 2), amt - 2);
        assertEq(nft.balanceOf(bsy, 4), 2);
        vm.stopPrank();

        // Bob transfers
        vm.startPrank(bob);
        nft.safeBatchTransferFrom(bob, address(snr), tokenIds, values, "");
        assertEq(nft.balanceOf(bob, 1), amt - 1);
        assertEq(nft.balanceOf(bob, 2), amt - 2);
        assertEq(nft.balanceOf(bob, 4), 2);
        vm.stopPrank();
        
        // Ace transfers
        vm.startPrank(ace);
        nft.safeBatchTransferFrom(ace, address(snr), tokenIds, values, "");
        assertEq(nft.balanceOf(ace, 1), amt - 1);
        assertEq(nft.balanceOf(ace, 2), amt - 2);
        assertEq(nft.balanceOf(ace, 4), 2);
        vm.stopPrank();

        // BSY transfers 1 of token 1, twice
        tokenIds[1] = 1;
        values[1] = 1;
        vm.startPrank(bsy);
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        assertEq(nft.balanceOf(bsy, 1), amt - 3);
        assertEq(nft.balanceOf(bsy, 2), amt - 2);
        assertEq(nft.balanceOf(bsy, 4), 4);
        vm.stopPrank();

        // BSY transfers 2 of token 2, twice
        tokenIds[0] = 2;
        tokenIds[1] = 2;
        values[0] = 2;
        values[1] = 2;
        vm.startPrank(bsy);
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        assertEq(nft.balanceOf(bsy, 1), amt - 3);
        assertEq(nft.balanceOf(bsy, 2), amt - 6);
        assertEq(nft.balanceOf(bsy, 4), 6);
        vm.stopPrank();

        // Withdraw nfts
        uint256 tokenOneAmt = 5;
        uint256 tokenTwoAmt = 10;
        assertEq(nft.balanceOf(address(snr), 1), tokenOneAmt);
        assertEq(nft.balanceOf(address(snr), 2), tokenTwoAmt);
        assertEq(nft.balanceOf(address(snr), 3), 0);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        values[0] = tokenOneAmt;
        values[1] = tokenTwoAmt;
        snr.withdraw_nfts(address(nft), tokenIds, values, address(0xdead));
        assertEq(nft.balanceOf(address(snr), 1), 0);
        assertEq(nft.balanceOf(address(snr), 2), 0);
        assertEq(nft.balanceOf(address(snr), 3), 0);
        assertEq(nft.balanceOf(address(0xdead), 1), tokenOneAmt);
        assertEq(nft.balanceOf(address(0xdead), 2), tokenTwoAmt);
        assertEq(nft.balanceOf(address(0xdead), 3), 0);
        assertEq(snr.num_redeemed(), 10);
    }

    function test_safeBatchTransferFrom_fuzz(uint256 amountOne, uint256 amountTwo) public {
        vm.assume(amountOne > 0 && amountTwo > 0);
        if (amountOne > amt) {
            amountOne = amountOne % amt + 1;
        }
        if (amountTwo > amt) {
            amountTwo = amountTwo % amt + 1;
        }

        ISendAndReceive.InputConfig[] memory configs = new ISendAndReceive.InputConfig[](2);
        configs[0] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 1,
            amount: amountOne
        });
        configs[1] = ISendAndReceive.InputConfig({
            contract_address: address(nft),
            token_id: 2,
            amount: amountTwo
        });

        snr.config_inputs(configs);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory values = new uint256[](2);
        values[0] = amountOne;
        values[1] = amountTwo;

        // BSY transfers 1 of token 1 and token 2
        vm.startPrank(bsy);
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        assertEq(nft.balanceOf(bsy, 1), amt - amountOne);
        assertEq(nft.balanceOf(bsy, 2), amt - amountTwo);
        assertEq(nft.balanceOf(bsy, 4), 2);
        assertEq(snr.num_redeemed(), 2);
        assertEq(nft.balanceOf(address(snr), 1), amountOne);
        assertEq(nft.balanceOf(address(snr), 2), amountTwo);
        vm.stopPrank();

        // withdraw nfts
        snr.withdraw_nfts(address(nft), tokenIds, values, address(0xdead));
        assertEq(nft.balanceOf(address(snr), 1), 0);
        assertEq(nft.balanceOf(address(snr), 2), 0);
        assertEq(nft.balanceOf(address(0xdead), 1), amountOne);
        assertEq(nft.balanceOf(address(0xdead), 2), amountTwo);
    }

    function test_pausable() public {
        snr.set_paused(true);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        // try transfers
        vm.startPrank(bsy);
        vm.expectRevert("pausable: contract is paused");
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        vm.expectRevert("pausable: contract is paused");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();

        // unpause
        snr.set_paused(false);
        vm.startPrank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");
        nft.safeBatchTransferFrom(bsy, address(snr), tokenIds, values, "");
        vm.stopPrank();
    }
}