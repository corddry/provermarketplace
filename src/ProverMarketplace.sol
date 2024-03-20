// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IVerifier.sol";

/// @title Prover Marketplace
/// @notice Allows users to request arbitrary validity proofs from a network of prover nodes
/// @dev Proofs are requested by emitting events, which are watched by prover nodes. The contract avoids storing
///      request detais on-chain to minimize gas costs
contract ProverMarketplace {
    /// @notice the fulfillment status of a proof request
    /// @dev Enums default to their first value on init, so statuses will default to NOT_FOUND. This is important in
    ///      preventing prover nodes from claiming bounties for requests that don't exist
    enum RequestStatus {
        NOT_FOUND,
        PENDING,
        FULFILLED
    }

    /// @notice maps request IDs to their fulfillment status
    /// @dev this is the only on-chain storage used by the contract
    mapping(bytes32 => RequestStatus) public idToRequestStatus;

    /// @notice emitted when a proof request is made.
    /// @dev Includes all of the information a node needs to fulfill a request without reading any contract storage.
    ///      Events can be indexed by sender, proof verifier, and program hash to allow nodes to specialize in
    ///      generating proofs for specific contracts, proof systems, or programs
    event ProofRequested(
        address indexed requester,
        address indexed verifier,
        bytes32 indexed programHash,
        uint256 bounty,
        address callbackContract,
        bytes4 callbackSelector,
        bytes input
    );
    /// @notice emitted when a proof request is fulfilled
    /// @dev The verified output of the program and corresponding proof can be read from this event
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

    /// @notice Thrown when a proof request is made without specifying a verifier
    error RequestMustIncludeVerifier();
    /// @notice Thrown when a proof request is made twice with identical parameters
    error RequestAlreadyExists();
    /// @notice Thrown when a node tries to fulfill a request that does not exist
    error RequestNotFound();
    /// @notice Thrown when a verifier does not accept a node's proof
    error ProofVerificationFailed();
    /// @notice Thrown when a node tries to fulfill a request that has already been fulfilled
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

    /// @notice emits a proof request event for verifiers watching the contract without triggering a callback function.
    ///         Function may be sent ether for a "bounty" to incentivize fulfillment
    /// @dev verified outputs can be read from the ProofFulfilled event upon fulfillment
    function requestProof(IVerifier verifier, bytes32 programHash, bytes calldata input) public payable {
        requestProofWithCallback(verifier, programHash, address(0), bytes4(0), input);
    }

    /// @notice emits a proof request event for verifiers watching the contract, including a callback function which
    ///         is called on proof fulfillment. Function may be sent ether for a "bounty" to incentivize fulfillment
    /// @dev Successful execution of callback function is not guranteed! Prover can claim bounty regardless of success
    function requestProofWithCallback(
        IVerifier verifier,
        bytes32 programHash,
        address callbackContract,
        bytes4 callbackSelector,
        bytes calldata input
    ) public payable {
        if (address(verifier) == address(0)) {
            revert RequestMustIncludeVerifier();
        }
        bytes32 requestID = getRequestID(verifier, programHash, msg.value, callbackContract, callbackSelector, input);

        if (idToRequestStatus[requestID] != RequestStatus.NOT_FOUND) {
            revert RequestAlreadyExists();
        }
        idToRequestStatus[requestID] = RequestStatus.PENDING;

        emit ProofRequested(
            msg.sender, address(verifier), programHash, msg.value, callbackContract, callbackSelector, input
        );
    }

    /// @notice returns false if the request's callback function call fails, true otherwise. Prover is paid regardless
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
        emit ProofFulfilled(
            msg.sender, address(verifier), programHash, bounty, callbackContract, callbackSelector, input, output, proof
        );

        // Interactions
        if (bounty > 0) {
            (bool sent,) = msg.sender.call{value: bounty}("");
            require(sent, "Failed to send Ether");
        }

        if (callbackContract == address(0)) {
            return true;
        }
        (bool success,) = callbackContract.call(abi.encodePacked(callbackSelector, output)); //TODO: make sure that the prover can't abuse this, for example, by intentionally running out of gass
        return success;
    }
}
