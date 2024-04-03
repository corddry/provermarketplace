// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract SimpleContract {
    uint256 public number;

    function setNumber(uint256 x) public {
        if (x == 0) {
            revert("Number cannot be 0!");
        }
        number = x;
    }
}
