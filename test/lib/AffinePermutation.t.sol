// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std-1.9.7/Test.sol";
import {AffinePermutation} from "src/lib/AffinePermutation.sol"; // <- update path if different

/// @notice Harness to expose library functions for testing
contract AffinePermutationHarness {
    function pickAB(uint256 N, bytes32 seed) external pure returns (uint256 A, uint256 B) {
        return AffinePermutation.pickAB(N, seed);
    }

    function permute(uint256 index, uint256 N, uint256 A, uint256 B) external pure returns (uint256) {
        return AffinePermutation.permute(index, N, A, B);
    }

    // Local gcd for assertions
    function gcd(uint256 x, uint256 y) external pure returns (uint256) {
        while (y != 0) {
            (x, y) = (y, x % y);
        }
        return x;
    }
}

contract AffinePermutationTest is Test {
    AffinePermutationHarness internal h;

    function setUp() public {
        h = new AffinePermutationHarness();
    }

    function test_pickABRevertsIfNTooSmall() public {
        bytes32 seed = keccak256("seed");
        vm.expectRevert(AffinePermutation.NTooSmall.selector);
        h.pickAB(1, seed);
    }

    function test_permuteRevertsIfIndexTooLarge() public {
        uint256 N = 10;
        vm.expectRevert(AffinePermutation.IndexTooLarge.selector);
        h.permute(N, N, 1, 0);
    }

    function test_permuteRevertsOnIndexEqN(uint16 Nraw, bytes32 seed) public {
        uint256 N = bound(uint256(Nraw), 2, 1000);
        (uint256 A, uint256 B) = h.pickAB(N, seed);
        vm.expectRevert(AffinePermutation.IndexTooLarge.selector);
        h.permute(N, N, A, B);
    }

    function test_pickABDeterministic() public {
        uint256 N = 100;
        bytes32 seed = keccak256("abc");
        (uint256 A1, uint256 B1) = h.pickAB(N, seed);
        (uint256 A2, uint256 B2) = h.pickAB(N, seed);
        assertEq(A1, A2, "A differs");
        assertEq(B1, B2, "B differs");
    }

    function test_pickABRangesAndCoprime(uint16 Nraw, bytes32 seed) public {
        uint256 N = bound(uint256(Nraw), 2, 20000);

        (uint256 A, uint256 B) = h.pickAB(N, seed);

        // Ranges
        assertGt(A, 0, "A must be in [1..N-1]");
        assertLt(A, N, "A must be in [1..N-1]");
        assertLt(B, N, "B must be in [0..N-1]");

        // Coprime requirement unless fallback to 1
        if (A != 1) {
            assertEq(h.gcd(A, N), 1, "A must be coprime to N when A != 1");
        }
    }

    function test_permutationIsBijective(uint8 Nraw, bytes32 seed) public {
        uint256 N = bound(uint256(Nraw), 2, 100_000);
        (uint256 A, uint256 B) = h.pickAB(N, seed);

        bool[] memory seen = new bool[](N);

        for (uint256 i = 0; i < N; i++) {
            uint256 j = h.permute(i, N, A, B);
            assertLt(j, N, "Out of range");
            assertTrue(!seen[j], "Duplicate hit, not injective");
            seen[j] = true;
        }
        for (uint256 k = 0; k < N; k++) {
            assertTrue(seen[k], "Not surjective");
        }
    }

    function test_NEquals2FallbackAIsOne() public {
        // For N = 2, the only valid A in [1..N-1] is 1, so the library should fall back to A = 1
        (uint256 A, uint256 B) = h.pickAB(2, keccak256("x"));
        assertEq(A, 1, "A should be 1 for N=2");

        bool[2] memory seen = [false, false];
        for (uint256 i = 0; i < 2; i++) {
            uint256 j = h.permute(i, 2, A, B);
            assertLt(j, 2);
            assertTrue(!seen[j], "Duplicate");
            seen[j] = true;
        }
    }

    function test_permuteMatchesRotationWhenAIsOne(uint16 Nraw, bytes32 seed) public {
        uint256 N = bound(uint256(Nraw), 2, 1000);
        // Recompute B exactly like the library
        uint256 B = uint256(keccak256(abi.encode(seed, uint8(1)))) % N;

        // Sample a few indices
        uint256 upper = N < 10 ? N : 10;
        for (uint256 i = 0; i < upper; i++) {
            uint256 j = h.permute(i, N, 1, B);
            assertEq(j, addmod(i, B, N), "Rotation mismatch");
        }
    }
}
