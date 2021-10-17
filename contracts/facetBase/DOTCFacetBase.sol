// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import '../interfaces/IDOTCFacetBase.sol';

import '../libraries/AppStorage.sol';
import '../utils/SafeMath.sol';
import '../utils/RandomHelper.sol';
import '../utils/SafeArray.sol';
import '../libraries/LibERC20.sol';
import '../libraries/LibStrings.sol';

import '../defines/dUser.sol';
import '../defines/dOrder.sol';
import '../defines/dRisk.sol';
import '../defines/dMiningPool.sol';
import '../defines/dStaking.sol';
import '../defines/dArbit.sol';
import '../defines/dCommon.sol';

/**
 * @dev DOTC facet base class
 */
abstract contract DOTCFacetBase is IDOTCFacetBase {
    using SafeMath for uint; 
     using SafeArray for uint[];
    LibAppStorage.AppStorage internal db;
    ConstInstance internal consts;

    uint constant nDOTCDecimals=1000000000000;
    uint constant nUsdtDecimals=1000000;

    uint nFirstTradeLockTime=3 minutes;//3 days;
    uint nOtherTradeLockTime=1 minutes;//1 days;
    //交易仲裁周期
    uint nArbitTimePeriod=6 minutes;//7 days;
    //封卡仲裁间隔周期
    uint nCardArbitPeriod=10 minutes;//TODO--180 days;

    uint nMinArbiterNum=2;

   function _lockToken(address userAddr,address token,uint lockAmount) internal {
      require(db.userTable.userAssets[userAddr][token].available >= lockAmount,"insufficient available balance");
      db.userTable.userAssets[userAddr][token].available=db.userTable.userAssets[userAddr][token].available.sub(lockAmount);
      db.userTable.userAssets[userAddr][token].locked=db.userTable.userAssets[userAddr][token].locked.add(lockAmount);
   } 

   function _unLockToken(address userAddr,address token,uint unLockAmount) internal {
      require(db.userTable.userAssets[userAddr][token].locked >= unLockAmount,"insufficient locked balance");
      db.userTable.userAssets[userAddr][token].available=db.userTable.userAssets[userAddr][token].available.add(unLockAmount);
      db.userTable.userAssets[userAddr][token].locked=db.userTable.userAssets[userAddr][token].locked.sub(unLockAmount);
   } 

   function _burnToken(address userAddr,address token,uint burnAmount) internal {
      require(db.userTable.userAssets[userAddr][token].available >=burnAmount,"insufficient available balance");
      db.userTable.userAssets[userAddr][token].available=db.userTable.userAssets[userAddr][token].available.sub(burnAmount);
      //销毁
      LibERC20.transfer(token,address(0),burnAmount); 
   }

   function _getPubDOTCPrice() internal view returns(uint dotcPrice){
        dotcPrice=db.daoData.oracleInfo.currentPrice;
        uint nMin=nDOTCDecimals/1000;
        if(dotcPrice<nMin){
            dotcPrice=nMin;
        }
   }

   function _calculateOrderFee(address token,uint feeRate,uint orderValue,uint dotcAmount,bool isCheckMax) internal view returns(FeeInfo memory feeInfo){
      if(feeRate<=0 || orderValue<=0){
         feeInfo.feeValue=0;
         feeInfo.feeType=CoinType.UNKNOWN;
         return feeInfo;
      }
      if(token==db.config.usdtContract){
         //usdt order
         feeInfo.feeValue=orderValue.mul(feeRate).div(10000);
         if(feeInfo.feeValue<nUsdtDecimals) feeInfo.feeValue=nUsdtDecimals;
         if(isCheckMax){
           if(feeInfo.feeValue>100*nUsdtDecimals) feeInfo.feeValue=100*nUsdtDecimals;
         }
         feeInfo.feeType=CoinType.USDT;
      }else{
         //non-usdt order
         feeInfo.feeValue=dotcAmount.mul(feeRate).div(10000);
         uint nMin=dotcAmount.mul(nUsdtDecimals).div(orderValue);
         if(feeInfo.feeValue<nMin) feeInfo.feeValue=nMin;
         if(isCheckMax){
            if(feeInfo.feeValue>100*nMin) feeInfo.feeValue=100*nMin;
         }
         
         feeInfo.feeType=CoinType.DOTC;
      }
   }

   function _backSELLAdOrderLeftFee(string calldata adOrderId) internal{
      if(db.orderTable.otcAdOrders[adOrderId].detail.leftAmount<=0) return;
      if(db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue<=0) return;
      if(db.orderTable.otcAdOrders[adOrderId].side==ExchangeSide.BUY) return;
      uint leftFeeValue=db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue.mul(db.orderTable.otcAdOrders[adOrderId].detail.leftAmount).div(db.orderTable.otcAdOrders[adOrderId].detail.totalAmount);
      //back left fee
      if(db.orderTable.otcAdOrders[adOrderId].depositInfo.feeType==CoinType.USDT){
         _unLockToken(db.orderTable.otcAdOrders[adOrderId].makerAddress,db.config.usdtContract,leftFeeValue);
         db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue=db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue.sub(leftFeeValue);
      }else if(db.orderTable.otcAdOrders[adOrderId].depositInfo.feeType==CoinType.DOTC){
        _unLockToken(db.orderTable.otcAdOrders[adOrderId].makerAddress,db.config.dotcContract,leftFeeValue);
        db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue=db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue.sub(leftFeeValue);
      }  
   }

   function _getBackRate() internal view returns(uint backRate){
      if(db.daoData.miningPool.poolTokens[db.config.dotcContract].initSupply<=0 || db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply<=0) backRate=0;
      uint nPeriodCount=backRate=db.daoData.miningPool.poolTokens[db.config.dotcContract].periodCount;
      backRate=db.daoData.miningPool.poolTokens[db.config.dotcContract].initBackRate.mul(700 ** nPeriodCount).div(1000 ** nPeriodCount);
   }

   function _getDOTCNumFromUSDT(uint usdtValue) internal view returns(uint dotcAmount){
      dotcAmount= usdtValue.mul(nDOTCDecimals).div(_getPubDOTCPrice()).mul(nDOTCDecimals).div(nUsdtDecimals);
   }

   function _RemoveExOrderFromList(string memory adOrderId,string memory exOrderId) internal {
      if(db.orderTable.otcAdOrderCounter[adOrderId].length<=0) return;
      for(uint i=0;i<db.orderTable.otcAdOrderCounter[adOrderId].length;i++){
         string memory mExOrder=db.orderTable.otcAdOrderCounter[adOrderId][i];
         if(LibStrings.StrCmp(mExOrder,exOrderId)){
            delete db.orderTable.otcAdOrderCounter[adOrderId][i];
            break;
         }
      }
   }

   function _queryUnlockedAmount(address userAddr,address token) internal view returns(uint canUnlocked,uint nonUnlocked){
     AssetLockInfo[] memory assetLockInfo=db.userTable.userLockedList[userAddr][token];
     if(assetLockInfo.length<=0){
        canUnlocked=0;
        nonUnlocked=0;
        return (canUnlocked,nonUnlocked);
     }
     for(uint i=0;i<assetLockInfo.length;i++){
        if(assetLockInfo[i].unlockDeadline>0 && !assetLockInfo[i].isUnLocked){
           if(block.timestamp>=assetLockInfo[i].unlockDeadline){
              canUnlocked=canUnlocked.add(assetLockInfo[i].amount);
           }else{
              nonUnlocked=nonUnlocked.add(assetLockInfo[i].amount);
           }
        }
     }
   }

   function _releaseUnlockedAmount(address userAddr,address token) internal returns(uint canUnlocked){
     AssetLockInfo[] memory assetLockInfo=db.userTable.userLockedList[userAddr][token];
     if(assetLockInfo.length<=0){
        canUnlocked=0;
        return canUnlocked;
     }
     for(uint i=0;i<assetLockInfo.length;i++){
        if(block.timestamp>=assetLockInfo[i].unlockDeadline && assetLockInfo[i].unlockDeadline>0 && !assetLockInfo[i].isUnLocked){
           //可解锁
           db.userTable.userAssets[userAddr][token].available=db.userTable.userAssets[userAddr][token].available.add(assetLockInfo[i].amount);
           db.userTable.userLockedList[userAddr][token][i].isUnLocked=true;
           db.userTable.userLockedList[userAddr][token][i].unlockDeadline=0;
           canUnlocked=canUnlocked.add(assetLockInfo[i].amount);
           delete db.userTable.userLockedList[userAddr][token][i];
        }
     }

   }

   function _addUnlockedAmount(address _userAddr,address _token,uint _amount,uint _timePeriod) internal{
      if(_amount<=0) return;
      AssetLockInfo memory assetLockInfo=AssetLockInfo(_amount,block.timestamp,false,block.timestamp.add(_timePeriod));
      db.userTable.userLockedList[_userAddr][_token].push(assetLockInfo);
   }

    //0-不能申请，1-付费申请，2-免费申请仲裁
    function _checkExArbitAccess(string calldata exOrderId) internal view returns(uint){
       if(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes==0){
          //first time
          return 1;
       }
       if(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes>0 && db.arbitTable.orderArbitList[exOrderId].state==ArbitState.Completed){
          //check arbit result
          uint lastApplyTime=db.arbitTable.orderArbitList[exOrderId].lastApplyTime;
          if(lastApplyTime>0){
            uint timeUsed=block.timestamp-lastApplyTime;
            if(timeUsed>nArbitTimePeriod*3){
               //over time
               return 0;
            }
            if(timeUsed>nArbitTimePeriod){
               //申请完毕超过7天，并且完结
               //如果没有结果，可免费申请仲裁
               if(db.arbitTable.orderArbitList[exOrderId].arbitResult==ArbitResult.None){
                  return 2;
               }
               //败诉方可在7天上诉期内支付100DOTC发起重新仲裁
               if(db.arbitTable.orderArbitList[exOrderId].arbitResult==ArbitResult.Appellee && db.arbitTable.orderArbitList[exOrderId].applyUser==msg.sender){
                  if(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes<2){
                     return 1;
                  }
               }
            }
          }

       }

       return 0;
    }
    function _findArbiterIndexForExOrder(ArbitInfo[] memory arbitList,address arbiter) internal pure returns(uint){
      if(arbitList.length<1) return 0;
      for(uint i=0;i<arbitList.length;i++){
         if(arbitList[i].arbiter==arbiter){
            return i+1;
         }
      }
      return 0;
    }
    function _getRandomArbiter(uint num) internal view returns(uint[] memory arbiterList){
      require(num>=nMinArbiterNum,'arbiter count is less than minimum');
      require(db.arbitTable.arbiterList.length>=num,'arbiter count is less than num');   
      uint[] memory randIndexs=_getRandomList(db.arbitTable.arbiterList.length,num);
      require(randIndexs.length==num,'get random list error');  
      arbiterList=new uint[](num);
      for(uint i=0;i<randIndexs.length;i++){
         arbiterList[i]=db.arbitTable.arbiterList[randIndexs[i]];
      }
      
    }
    function _getRandomList(uint nLength,uint num) internal view returns(uint[] memory indexList){
      require(nLength>=num,'the length is less than target num');
      uint nonce=nLength/2;
      uint nTryTimes=0;
      indexList=new uint[](num);
      uint nCurrentIndex=0;
      {
         while(nCurrentIndex<num){
            nonce++;nTryTimes++;
            if(nTryTimes>100){
               //overflow
               break;
            }
            uint nIndex=RandomHelper.rand(nLength,nonce);
            (bool isFind,uint index)=indexList.Contains(nIndex);
            if(!isFind && index<=0){
               indexList[nCurrentIndex]=nIndex;
               nCurrentIndex++;
            }
         }
      }
     
    }
    function _rewardDOTCToArbiter(ArbitInfo[] memory arbitInfoList,uint totalReward,uint ArbiterNum,ArbitResult arbitResult ) internal{
      if(arbitInfoList.length>0 && ArbiterNum>0 && totalReward>0){
         uint nSingleReward=totalReward.div(ArbiterNum);
         for(uint i=0;i<arbitInfoList.length;i++){
            if(arbitInfoList[i].arbiter!=address(0) && arbitInfoList[i].result==arbitResult){
               //give token
               db.userTable.userAssets[arbitInfoList[i].arbiter][db.config.dotcContract].available=db.userTable.userAssets[arbitInfoList[i].arbiter][db.config.dotcContract].available.add(nSingleReward);
            }
         }
      }
    }
    
    function _queryResultCount(ArbitInfo[] memory arbitInfoList) internal pure returns(uint AccuserCount,uint AppelleeCount ){
      if(arbitInfoList.length>0){
         for(uint i=0;i<arbitInfoList.length;i++){
            if(arbitInfoList[i].result==ArbitResult.Accuser){
               AccuserCount++;
            }else if(arbitInfoList[i].result==ArbitResult.Appellee){
               AppelleeCount++;
            }
         }
      }
    }


}