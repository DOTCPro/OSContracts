// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

struct OracleInfo{
    uint currentPrice;
    bool isInited;
    uint lastUpdateTime;
}
struct Config{
    address dotcContract;
    address wethContract;
    address usdtContract;
    address mainContract;
            /***FEE */
    uint makerFee;
    uint takerFee;
}
//constant
struct ConstInstance{
    uint priceMode;
    uint vipDOTC;
    uint arbiterDOTC;
    ArbitParam arbitParam;
    StakingParam stakingParam;
}
struct ArbitParam{
    uint nArbitNum;
    uint nOrderArbitCost;
    uint nCardArbitCost;
}
struct StakingParam{
    uint poolAMin;
    uint poolBMin;
    uint unLockWaitTime;
    uint bonusUnlockTime;
    uint firstBonusTime;
    uint bonusWaitTime;
}

