// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRLBTRFLY {
        function lock(address account, uint256 amount) external;
        function lockedBalanceOf(address account)external view returns (uint256 amount);
        function processExpiredLocks(bool relock) external;
        function balanceOf(address account) external view returns (uint256 amount);
        function pendingLockOf(address account)external view returns (uint256 amount);
        function withdrawExpiredLocksTo(address to) external;
    
    }

















