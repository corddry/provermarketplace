// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ProverMarketplace} from "../src/ProverMarketplace.sol";
import {IVerifier} from "../src/IVerifier.sol";
import {DummyVerifier} from "../src/DummyVerifier.sol";

contract CounterTest is Test {
    // Define events for forge emit expectations
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

    ProverMarketplace public marketplace;
    IVerifier public verifier;
    SimpleContract public callbackContract;

    // Sample Request Fields
    bytes32 public programHash = hex"111111";
    uint256 public bounty = 0.1 ether;
    bytes4 public callbackSelector = callbackContract.setNumber.selector;
    bytes public input = hex"222222";
    bytes public dummyProof = hex"333333";
    bytes public dummyOutput = abi.encodePacked(uint256(1337)); // 0x0...0539

    // Example Request IDs
    bytes32 public requestID;
    bytes32 public requestIDNoBounty;
    bytes32 public requestIDNoCallback;

    // Make the test contract payable to test bounties
    receive() external payable {}

    function setUp() public {
        // Deploy contracts
        marketplace = new ProverMarketplace();
        verifier = new DummyVerifier();
        callbackContract = new SimpleContract();

        // Calculate example request IDs
        requestID =
            marketplace.getRequestID(verifier, programHash, bounty, address(callbackContract), callbackSelector, input);
        requestIDNoBounty =
            marketplace.getRequestID(verifier, programHash, 0, address(callbackContract), callbackSelector, input);
        requestIDNoCallback = marketplace.getRequestID(verifier, programHash, bounty, address(0), bytes4(0), input);
    }

    function test_Init() public {
        assert(marketplace.idToRequestStatus(0) == ProverMarketplace.RequestStatus.NOT_FOUND);
    }

    // Test requestProof with all parameters
    function test_RequestProofFull() public {
        vm.expectEmit();
        emit ProofRequested(
            address(this), address(verifier), programHash, bounty, address(callbackContract), callbackSelector, input
        );
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );
        assert(marketplace.idToRequestStatus(requestID) == ProverMarketplace.RequestStatus.PENDING);
    }

    // Test requestProof without specifying a callback
    function test_RequestProofNoCallback() public {
        vm.expectEmit();
        emit ProofRequested(address(this), address(verifier), programHash, bounty, address(0), bytes4(0), input);
        marketplace.requestProof{value: 0.1 ether}(verifier, programHash, input);
        assert(marketplace.idToRequestStatus(requestIDNoCallback) == ProverMarketplace.RequestStatus.PENDING);
    }

    // Test requestProof without offering a bounty
    function test_RequestProofNoBounty() public {
        vm.expectEmit();
        emit ProofRequested(
            address(this), address(verifier), programHash, 0, address(callbackContract), callbackSelector, input
        );
        marketplace.requestProofWithCallback(verifier, programHash, address(callbackContract), callbackSelector, input);
        assert(marketplace.idToRequestStatus(requestIDNoBounty) == ProverMarketplace.RequestStatus.PENDING);
    }

    // Ensure a request with a verifier address of 0 reverts with custom error
    function test_RequestProofZeroVerifier() public {
        vm.expectRevert(ProverMarketplace.RequestMustIncludeVerifier.selector);
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            IVerifier(address(0)), programHash, address(callbackContract), callbackSelector, input
        );
    }

    // Ensure a request made twice with identical parameters reverts with custom error
    function test_RequestProofTwice() public {
        marketplace.requestProof{value: 0.1 ether}(verifier, programHash, input);
        vm.expectRevert(ProverMarketplace.RequestAlreadyExists.selector);
        marketplace.requestProof{value: 0.1 ether}(verifier, programHash, input);
    }

    // Test a standard proof fulfillment
    function test_FulfillProof() public {
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );

        vm.expectEmit();
        emit ProofFulfilled(
            address(this),
            address(verifier),
            programHash,
            bounty,
            address(callbackContract),
            callbackSelector,
            input,
            dummyOutput,
            dummyProof
        );
        marketplace.fulfillProof(
            verifier, programHash, bounty, address(callbackContract), callbackSelector, input, dummyOutput, dummyProof
        );

        assert(marketplace.idToRequestStatus(requestID) == ProverMarketplace.RequestStatus.FULFILLED);
    }

    // Test a proof fulfillment with a callback function that successfully executes
    function test_FulfillCallbackSuccess() public {
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );

        vm.expectEmit();
        emit ProofFulfilled(
            address(this),
            address(verifier),
            programHash,
            bounty,
            address(callbackContract),
            callbackSelector,
            input,
            dummyOutput,
            dummyProof
        );
        assert(
            marketplace.fulfillProof(
                verifier,
                programHash,
                bounty,
                address(callbackContract),
                callbackSelector,
                input,
                dummyOutput,
                dummyProof
            )
        );

        assert(marketplace.idToRequestStatus(requestID) == ProverMarketplace.RequestStatus.FULFILLED);
        assertEq(callbackContract.number(), uint256(1337));
    }

    // Test a proof fulfillment with a callback function that unsuccessfully executes
    function test_FulfillCallbackFailure() public {
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );

        vm.expectEmit();
        emit ProofFulfilled(
            address(this),
            address(verifier),
            programHash,
            bounty,
            address(callbackContract),
            callbackSelector,
            input,
            abi.encodePacked(uint256(0)),
            dummyProof
        );
        assert(
            !marketplace.fulfillProof(
                verifier,
                programHash,
                bounty,
                address(callbackContract),
                callbackSelector,
                input,
                abi.encodePacked(uint256(0)),
                dummyProof
            )
        );

        assert(marketplace.idToRequestStatus(requestID) == ProverMarketplace.RequestStatus.FULFILLED);
        assertEq(callbackContract.number(), uint256(0));
    }

    // Ensure that bounties are correctly awarded after fulfillment
    function test_FulfillBountyAwarded() public {
        assert(address(marketplace).balance == 0 ether);
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );
        assert(address(marketplace).balance == 0.1 ether);

        uint256 initialBalance = address(this).balance;
        marketplace.fulfillProof(
            verifier, programHash, bounty, address(callbackContract), callbackSelector, input, dummyOutput, dummyProof
        );
        assertEq(address(this).balance, initialBalance + bounty);

        assert(marketplace.idToRequestStatus(requestID) == ProverMarketplace.RequestStatus.FULFILLED);
    }

    // Ensure that fulfillments of nonexistant requests revert with custom error
    function test_RequestNotFound() public {
        vm.expectRevert(ProverMarketplace.RequestNotFound.selector);
        marketplace.fulfillProof(
            verifier, programHash, bounty, address(callbackContract), callbackSelector, input, dummyOutput, dummyProof
        );
    }

    // Ensure that fulfillments with failed verifications revert with custom error
    function test_VerificationFailed() public {
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );

        DummyVerifier(address(verifier)).toggleResult();
        vm.expectRevert(ProverMarketplace.ProofVerificationFailed.selector);
        marketplace.fulfillProof(
            verifier, programHash, bounty, address(callbackContract), callbackSelector, input, dummyOutput, dummyProof
        );
    }

    // Ensure that fulfillments of already fulfilled requests revert with custom error
    function test_AlreadyFulFilled() public {
        marketplace.requestProofWithCallback{value: 0.1 ether}(
            verifier, programHash, address(callbackContract), callbackSelector, input
        );

        vm.expectEmit();
        emit ProofFulfilled(
            address(this),
            address(verifier),
            programHash,
            bounty,
            address(callbackContract),
            callbackSelector,
            input,
            dummyOutput,
            dummyProof
        );
        marketplace.fulfillProof(
            verifier, programHash, bounty, address(callbackContract), callbackSelector, input, dummyOutput, dummyProof
        );

        vm.expectRevert(ProverMarketplace.RequestAlreadyFulfilled.selector);
        marketplace.fulfillProof(
            verifier, programHash, bounty, address(callbackContract), callbackSelector, input, dummyOutput, dummyProof
        );
    }
}

// Simple contract for testing callback functionality
contract SimpleContract {
    uint256 public number;

    function setNumber(uint256 x) public {
        if (x == 0) {
            revert("Number cannot be 0!");
        }
        number = x;
    }
}
