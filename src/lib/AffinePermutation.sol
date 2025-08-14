// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Affine Permuation Library
/// @notice Library to compute Affine Permutations, making raffle choices O(1) based on a constant seed and N > 1
/// @dev Permutations are like shuffling a deck of cards and is cheaper than drawing cards from the metaphorical deck.
///      The Affine Permutation is O(1) in difficulty and is perfectly reproducible. It can be used to get exactly K winners for raffle applications.
/// @author Transient Labs, Inc
/// @custom:version 2.0.0
library AffinePermutation {
    ////////////////////////////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////////////////////////////

    uint256 private constant MAX_COPRIME_SEARCH_ATTEMPTS = 32;

    ////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////

    error NTooSmall();
    error IndexTooLarge();

    ////////////////////////////////////////////////////////////////////////////
    // Functions
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Function to pick coefficients (A,B)
    /// @dev N must be greater than 1
    /// @dev Tries to avoid the situation where A = 1, but falls back to it
    ///      A = 1 is a valid permutation, but it looks like a simple rotation, which is not ideal from a marketing perspective
    function pickAB(uint256 N, bytes32 seed) internal pure returns (uint256 A, uint256 B) {
        // revert if too small
        if (N < 2) revert NTooSmall();

        // choose B
        B = uint256(keccak256(abi.encode(seed, uint8(1)))) % N;

        // Find A - prefer A != 1
        A = _findCoprimeNotOne(N, uint256(keccak256(abi.encode(seed, uint8(2)))));

        // try again with a new hash
        if (A == 0) A = _findCoprimeNotOne(N, uint256(keccak256(abi.encode(seed, uint8(3)))));

        // last resort: rotation. Still a permutation, just less “scrambled.”
        if (A == 0) A = 1;
    }

    /// @notice Permute an index into [0..N-1] using rank = (A*index + B) mod N.
    function permute(uint256 index, uint256 N, uint256 A, uint256 B) internal pure returns (uint256) {
        // ensure index is less than N
        if (index >= N) revert IndexTooLarge();

        // permute
        return addmod(mulmod(A, index, N), B, N);
    }

    /// @notice Function to find a coprime A
    /// @dev Tries up to 32 sequential candidates from an initial 256-bit sample.
    function _findCoprimeNotOne(uint256 N, uint256 sample) private pure returns (uint256 A) {
        // N >= 2 guaranteed by the caller
        unchecked {
            uint256 span = N - 1; // valid A are in [1..span]
            uint256 start = (sample % span) + 1; // [1..span]
            for (uint256 i = 0; i < MAX_COPRIME_SEARCH_ATTEMPTS; ++i) {
                // walk the ring [1..span] without ever leaving it
                uint256 a = 1 + ((start - 1 + i) % span); // stays in [1..span]
                if (a != 1 && _gcd(a, N) == 1) return a; // prefer a != 1
            }
        }
        // no suitable candidate found within attempts
        return 0;
    }

    /// @notice Function to calculate the greatest common divisor
    function _gcd(uint256 x, uint256 y) private pure returns (uint256) {
        while (y != 0) (x, y) = (y, x % y);
        return x;
    }
}
