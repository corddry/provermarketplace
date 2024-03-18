pragma solidity ^0.8.0;

contract DummyVerifier {
    function verify(bytes32 programHash, bytes memory input, bytes memory output, bytes memory proof) external pure returns (bool) {
        return true;
    }
}