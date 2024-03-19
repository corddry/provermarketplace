// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./IVerifier.sol";

contract DummyVerifier is IVerifier {
    bool public result = true;
    function verify(bytes32 programHash, bytes memory input, bytes memory output, bytes memory proof) external view returns (bool) {
        return result;
    }
    function toggleResult() public {
        result = !result;
    }    
}