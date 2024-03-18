// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IVerifier {
    function verify(bytes32 programHash, bytes calldata input, bytes calldata output, bytes calldata proof)
        external
        returns (bool);
}

contract ProverMarketplace {
    struct request {
        IVerifier verifier;
        uint256 bounty;
        address callbackAddress;
        bytes4 callbackSelector;
        bool isFulfilled;
    }

    mapping(bytes32 => request) public idToRequest;

    event ProofRequested(
        address indexed requester, address indexed verifier, bytes32 indexed programHash, uint256 bounty, bytes input
    );
    event ProofFulfilled(
        address indexed prover,
        address indexed verifier,
        bytes32 indexed programHash,
        bytes input,
        bytes output,
        bytes proof
    );

    error ProofRequestMustIncludeVerifier();

    error RequestNotFound();
    error ProofVerificationFailed();
    error RequestAlreadyFulfilled();

    function requestProof(IVerifier verifier, bytes32 programHash, bytes calldata input) public payable {
        requestProofWithCallback(verifier, programHash, address(0), bytes4(0), input);
    }

    function requestProofWithCallback(
        IVerifier verifier,
        bytes32 programHash,
        address callbackAddress,
        bytes4 callbackSelector,
        bytes calldata input
    ) public payable {
        if (address(verifier) == address(0)) {
            revert ProofRequestMustIncludeVerifier();
        }

        bytes32 requestID = keccak256(abi.encodePacked(address(verifier), programHash, input));
        // require(idToRequest[requestID].verifier == address(0), "Request already exists"); // Change this if we want to allow for multiple requests for the same programHash and input ie, multiple callbacks
        idToRequest[requestID] = request(verifier, msg.value, callbackAddress, callbackSelector, false);
        emit ProofRequested(msg.sender, address(verifier), programHash, msg.value, input);
    }

    function fulfillProof( // TODO: May be vulnerable to reentrancy via callback!!!
    IVerifier verifier, bytes32 programHash, bytes calldata input, bytes calldata output, bytes calldata proof)
        public
    {
        bytes32 requestID = keccak256(abi.encodePacked(address(verifier), programHash, input));

        request storage req = idToRequest[requestID];

        if (address(req.verifier) == address(0)) {
            revert RequestNotFound();
        }
        if (req.isFulfilled) {
            revert RequestAlreadyFulfilled();
        }
        if (!verifier.verify(programHash, input, output, proof)) {
            revert ProofVerificationFailed();
        }

        req.isFulfilled = true;

        // (bool success, ) = req.callbackAddress.call(abi.encodeWithSelector(req.callbackSelector, input, output, proof)); // TODO: Callback
        // Send eth to prover

        emit ProofFulfilled(msg.sender, address(verifier), programHash, input, output, proof);
    }
}
