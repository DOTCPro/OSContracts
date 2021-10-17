// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

interface IDOTCManageFacet {
    event _UnitUpdated(address indexed dotcAddr,address indexed wethAddr);
    event ManagerTransferred(address indexed previousManager, address indexed newManager);
    event _PriceModeChanged(address userAddr,uint mode);
    event _PriceManualChanged(address userAddr,uint price);
    event _VIPConditionUpdated(address userAddr,uint amount);
    event _ArbitConditionUpdated(address userAddr,uint amount);
    event _StakingTimeUpdated(address userAddr,uint time);
    event _StakingParamUpdated(address userAddr,bool enableLock,bool enableUnLock,bool enableBonus);
    event _StakingMinUpdated(address userAddr,uint poolAMin,uint poolBMin);
    event _ArbitParamUpdated(address userAddr,uint nOrderArbitCost,uint nCardArbitCost);
    event _UnlockParamUpdated(address userAddr,uint unLockWaitTime,uint bonusUnlockTime);
    event _BonusParamUpdated(address userAddr,uint firstBonusTime,uint bonusWaitTime);
    
}
