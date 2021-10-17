// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

struct StakingDetail{
    uint balance;
    uint lastLockTime;
    uint weightTime;
    uint lastBonusTime;
    uint totalBonused;
}
struct StakingPool {
    // user address => balance
    mapping(address => StakingDetail) accountStakings;
    uint totalSupply;
    uint totalAccount;

    uint totalUSDTBonus;
    uint totalBonused;
}
struct StakingTable{
   uint startTime;
   bool isEnableLock;
   bool isEnableUnLock;
   bool isEnableBonus;

   mapping(address => StakingPool) poolA;
   mapping(address => StakingPool) poolB;
}