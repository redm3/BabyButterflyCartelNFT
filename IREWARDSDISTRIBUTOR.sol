// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//@param  claims  Claim[] List of claim metadata
//claims (tuple[])
    struct Claim {
        address token;
        address account;
        uint256 amount;
        bytes32[] merkleProof;
    }

    interface IREWARDSDISTRIBUTOR {
        function claim(Claim[] calldata claims) external;
        }







