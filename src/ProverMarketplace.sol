// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IVerifier.sol";

contract ProverMarketplace {
    enum RequestStatus {
        NOT_FOUND, // Default value on init
        PENDING,
        FULFILLED
    }

    mapping(bytes32 => RequestStatus) public idToRequestStatus;

    /// @dev Proof requests/fulfillments events can be indexed by sender, proof verifier, and program hash
    event ProofRequested(
        address indexed requester,
        address indexed verifier,
        bytes32 indexed programHash,
        uint256 bounty,
        address callbackContract,
        bytes4 callbackSelector,
        bytes input
    );
    event ProofFulfilled(
        address indexed prover,
        address indexed verifier,
        bytes32 indexed programHash,
        uint256 bounty,
        address callbackContract,
        bytes4 callbackSelector,
        bytes input,
        bytes output,
        bytes proof
    );

    // Proof Request Errors
    error ProofRequestMustIncludeVerifier();

    // Proof Fulfillment Errors
    error RequestNotFound();
    error ProofVerificationFailed();
    error RequestAlreadyFulfilled();

    /// @notice calculates the request ID of a proof request
    function getRequestID(
        IVerifier verifier,
        bytes32 programHash,
        uint256 bounty,
        address callbackContract,
        bytes4 callbackSelector,
        bytes calldata input
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(address(verifier), programHash, bounty, callbackContract, callbackSelector, input)
        );
    }

    /// @notice emits a proof request event for verifiers watching the contract
    function requestProof(IVerifier verifier, bytes32 programHash, bytes calldata input) public payable {
        requestProofWithCallback(verifier, programHash, address(0), bytes4(0), input);
    }

    /// @notice emits a proof request event for verifiers watching the contract, including a callback function which is called on proof fulfillment
    function requestProofWithCallback(
        IVerifier verifier,
        bytes32 programHash,
        address callbackContract,
        bytes4 callbackSelector,
        bytes calldata input
    ) public payable {
        if (address(verifier) == address(0)) { // Verifier must be set
            revert ProofRequestMustIncludeVerifier();
        }
        bytes32 requestID = getRequestID(verifier, programHash, msg.value, callbackContract, callbackSelector, input);
        idToRequestStatus[requestID] = RequestStatus.PENDING;
        emit ProofRequested(
            msg.sender, address(verifier), programHash, msg.value, callbackContract, callbackSelector, input
        );
    }

    /// @notice returns false if the request's callback function call fails, true otherwise. Payment will be made to the prover regardless.
    /// @dev this function follows the "Checks-Effects-Interactions" pattern to avoid reentrancy attacks via the callback function
    function fulfillProof(
        IVerifier verifier,
        bytes32 programHash,
        uint256 bounty,
        address callbackContract,
        bytes4 callbackSelector,
        bytes calldata input,
        bytes calldata output,
        bytes calldata proof
    ) public returns (bool) {
        bytes32 requestID = getRequestID(verifier, programHash, bounty, callbackContract, callbackSelector, input);

        // Checks
        RequestStatus status = idToRequestStatus[requestID];
        if (status == RequestStatus.NOT_FOUND) {
            revert RequestNotFound();
        }
        if (status == RequestStatus.FULFILLED) {
            revert RequestAlreadyFulfilled();
        }
        if (!verifier.verify(programHash, input, output, proof)) {
            revert ProofVerificationFailed();
        }

        // Effects
        idToRequestStatus[requestID] = RequestStatus.FULFILLED;
        emit ProofFulfilled(msg.sender, address(verifier), programHash, bounty, callbackContract, callbackSelector, input, output, proof);

        // Interactions
        if (bounty > 0) {
            (bool sent, ) = msg.sender.call{value: bounty}("");
            require(sent, "Failed to send Ether");
        }

        if (callbackContract == address(0)) {
            return true;
        }
        (bool success, ) = callbackContract.call(abi.encodePacked(callbackSelector, output)); //TODO: make sure that the prover can't abuse this, for example, by intentionally running out of gass
        return success;
    }
}
