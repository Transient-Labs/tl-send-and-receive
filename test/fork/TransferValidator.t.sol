// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std-1.9.7/Test.sol";
import {SendAndReceiveERC1155TL} from "src/SendAndReceiveERC1155TL.sol";
import {SendAndReceiveERC1155TLRaffle} from "src/SendAndReceiveERC1155TLRaffle.sol";
import {ERC1155TL} from "tl-creator-contracts-4.1.1/erc-1155/ERC1155TL.sol";

/// @notice Fork tests against Limit Break's live Creator Token Transfer Validator V5
/// @dev Skipped when ETH_RPC_URL is not set (e.g. in CI)
contract TransferValidatorForkTest is Test {
    address constant TRANSFER_VALIDATOR_V5 = 0x721C008fdff27BF06E7E123956E2Fe03B63342e3;
    uint256 constant FORK_BLOCK = 26206978;

    SendAndReceiveERC1155TL public snr;
    SendAndReceiveERC1155TLRaffle public raffle;
    ERC1155TL public nft;

    address sink = address(0x5151);
    address bsy = address(0x42069);
    address bob = address(0xB0B);

    bytes32 seed = keccak256("seed");
    string salt = "salt";

    function setUp() public {
        if (bytes(vm.envOr("ETH_RPC_URL", string(""))).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork("mainnet", FORK_BLOCK);

        // setup ERC1155TL with the live transfer validator and royalties enabled (validator only runs if royalty > 0)
        nft = new ERC1155TL(false);
        nft.initialize(
            "Token", "TKN", address(this), 1000, address(this), new address[](0), true, TRANSFER_VALIDATOR_V5, 0
        );
        assertEq(nft.getTransferValidator(), TRANSFER_VALIDATOR_V5);
        address[] memory addys = new address[](2);
        addys[0] = bsy;
        addys[1] = bob;
        uint256[] memory amts = new uint256[](2);
        amts[0] = 10;
        amts[1] = 10;
        nft.createToken("uri1", addys, amts);
        nft.createToken("uri2", addys, amts);
        amts[0] = 0;
        amts[1] = 0;
        nft.createToken("uri3", addys, amts);

        // setup SendAndReceiveERC1155TL
        SendAndReceiveERC1155TL.Settings memory snrSettings = SendAndReceiveERC1155TL.Settings({
            closed: false,
            outputContractAddress: address(nft),
            outputTokenId: 3,
            inputTokenSink: sink,
            openAt: uint64(block.timestamp),
            duration: uint64(48 hours),
            maxRedemptions: uint64(100),
            numRedeemed: uint64(0)
        });
        SendAndReceiveERC1155TL.InputConfig[] memory inputConfigs = new SendAndReceiveERC1155TL.InputConfig[](2);
        inputConfigs[0] = SendAndReceiveERC1155TL.InputConfig({contractAddress: address(nft), tokenId: 1, amount: 1});
        inputConfigs[1] = SendAndReceiveERC1155TL.InputConfig({contractAddress: address(nft), tokenId: 2, amount: 2});
        snr = new SendAndReceiveERC1155TL(false);
        snr.initialize(address(this), snrSettings, inputConfigs);

        // setup SendAndReceiveERC1155TLRaffle
        SendAndReceiveERC1155TLRaffle.Settings memory raffleSettings = SendAndReceiveERC1155TLRaffle.Settings({
            canceled: false,
            outputContractAddress: address(nft),
            outputTokenId: 3,
            inputContractAddress: address(nft),
            inputTokenId: 1,
            inputAmount: 1,
            inputTokenSink: sink,
            openAt: uint64(block.timestamp),
            duration: uint64(48 hours),
            numWinners: uint64(1),
            numEntries: uint64(0)
        });
        raffle = new SendAndReceiveERC1155TLRaffle(false);
        raffle.initialize(address(this), raffleSettings, keccak256(abi.encode(seed, salt)));

        // set mint contracts
        address[] memory mintContracts = new address[](2);
        mintContracts[0] = address(snr);
        mintContracts[1] = address(raffle);
        nft.setApprovedMintContracts(mintContracts, true);
    }

    /// @dev Control: proves the validator is enforcing, so the passing transfers below are meaningful
    function test_validatorBlocksUnapprovedOperator() public {
        address operator = address(0xBEEF);
        vm.prank(bsy);
        nft.setApprovalForAll(operator, true);

        vm.prank(operator);
        vm.expectRevert();
        nft.safeTransferFrom(bsy, bob, 1, 1, "");
    }

    function test_singleTransfer() public {
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(snr), 1, 1, "");

        assertEq(nft.balanceOf(sink, 1), 1);
        assertEq(nft.balanceOf(bsy, 3), 1);
    }

    function test_batchTransfer() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 2;

        vm.prank(bsy);
        nft.safeBatchTransferFrom(bsy, address(snr), ids, values, "");

        assertEq(nft.balanceOf(sink, 1), 1);
        assertEq(nft.balanceOf(sink, 2), 2);
        assertEq(nft.balanceOf(bsy, 3), 2);
    }

    function test_raffle_revealAndClaim() public {
        _enterRaffle();

        // reveal
        vm.warp(block.timestamp + 48 hours);
        raffle.reveal(seed, salt);

        // claim: one winner (editions sunk + output minted), one refund (editions returned)
        raffle.claim(bsy);
        raffle.claim(bob);

        assertEq(nft.balanceOf(sink, 1), 1);
        assertEq(nft.balanceOf(bsy, 3) + nft.balanceOf(bob, 3), 1);
        assertEq(nft.balanceOf(bsy, 1) + nft.balanceOf(bob, 1), 19);
        assertEq(nft.balanceOf(address(raffle), 1), 0);
    }

    function test_raffle_cancelAndRefund() public {
        _enterRaffle();

        // cancel after the reveal window passes
        vm.warp(block.timestamp + 48 hours + raffle.REVEAL_TIME_ALLOTMENT());
        raffle.cancel();

        // refunds
        raffle.claim(bsy);
        raffle.claim(bob);

        assertEq(nft.balanceOf(bsy, 1), 10);
        assertEq(nft.balanceOf(bob, 1), 10);
        assertEq(nft.balanceOf(address(raffle), 1), 0);
    }

    function _enterRaffle() private {
        vm.prank(bsy);
        nft.safeTransferFrom(bsy, address(raffle), 1, 1, "");
        vm.prank(bob);
        nft.safeTransferFrom(bob, address(raffle), 1, 1, "");
        assertEq(nft.balanceOf(address(raffle), 1), 2);
    }
}
