// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVerifier {
    function verify(bytes32 programHash, bytes calldata input, bytes calldata output, bytes calldata proof)
        external
        returns (bool);
}