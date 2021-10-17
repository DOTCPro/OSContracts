// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

struct RiskPool{
   mapping(address => PoolInfo) poolTokens;
}

struct PoolInfo{
   uint initSupply;
   uint currentSupply;
   uint totalPayed;
   uint payTimes;
}


