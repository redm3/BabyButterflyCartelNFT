// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Common {
    struct Claim {
        address token;
        address account;
        uint256 amount;
        bytes32[] merkleProof;
    }
}

    interface IRewardDistributor {
            function claim(Common.Claim[] calldata claims) external;

    }






