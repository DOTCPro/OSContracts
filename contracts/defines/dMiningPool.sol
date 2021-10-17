// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

struct MiningPool{
   mapping(address => MineInfo) poolTokens;
}

struct MineInfo{
   uint initSupply;
   uint initBackRate;
   uint currentSupply;
   uint totalMined;
   uint periodMined;
   uint periodCount;
}

