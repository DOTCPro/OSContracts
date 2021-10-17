// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../facetBase/DOTCFacetBase.sol";
//import "../facetBase/DOTCArbitBase.sol";

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";
import '../utils/SafeMath.sol';
import '../utils/SafeArray.sol';

contract DOTCCardAribtFacet is DOTCFacetBase {
    using SafeMath for uint; 
    using SafeArray for uint[];
    event _CardArbitCreated(address userAddr,uint usdtAmount); 
    event _CardArbitCancelled(address userAddr); 
    event _CardArbitResultGived(address aribtAddr,address userAddr,uint result); 
    event _CardArbitResultUpdated(address senderAddr,address userAddr,uint AccuserCount,uint AppelleeCount);
    /************************* Card Arbit ******************/
    function createCardArbit(string calldata arbitId,uint usdtAmount) external returns(bool result){
     {
        require(usdtAmount>0,'amount must be greater than 0');
        require(db.userTable.userList[msg.sender].isVIP,'only vip user can apply card arbit');
        require(db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply>0,'risk pool is empty');
        uint dotcAmount=_getDOTCNumFromUSDT(usdtAmount);
        require(db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply>=dotcAmount,'insufficient risk pool supply');
        CardArbit memory cardArbit=db.arbitTable.carArbitList[msg.sender];
        require(cardArbit.state!=ArbitState.Dealing,'you have an arbit in process.');
        require(cardArbit.lastApplyTime==0 || (block.timestamp-cardArbit.lastApplyTime)<=nCardArbitPeriod,'you have an arbit within 180 days.');
        require(usdtAmount<=10000*nUsdtDecimals,'you can apply up to 10000usdt.');
     }
     {
       if(consts.arbitParam.nCardArbitCost>0){
         _lockToken(msg.sender,db.config.dotcContract,consts.arbitParam.nCardArbitCost);
       } 
       db.arbitTable.carArbitList[msg.sender].lockedDotcAmount=consts.arbitParam.nCardArbitCost;
     }
     {
        //create card arbit
        db.arbitTable.carArbitList[msg.sender].arbitID=arbitId;
        db.arbitTable.carArbitList[msg.sender].applyUSDTAmount=usdtAmount;
        db.arbitTable.carArbitList[msg.sender].state=ArbitState.Dealing;
        db.arbitTable.carArbitList[msg.sender].lastApplyTime=block.timestamp;
        db.arbitTable.carArbitList[msg.sender].arbitResult=ArbitResult.None;
        db.arbitTable.carArbitList[msg.sender].lastCompleteTime=0;
        db.arbitTable.carArbitList[msg.sender].cardArbitTimes++;
     }
     {
        //give arbiters
        if(consts.arbitParam.nArbitNum<nMinArbiterNum) consts.arbitParam.nArbitNum=nMinArbiterNum;
        uint[] memory arbiterList=_getRandomArbiter(consts.arbitParam.nArbitNum);
        for(uint i=0;i<arbiterList.length;i++){
           db.arbitTable.cardArbitDetailList[msg.sender].push(ArbitInfo(address(arbiterList[i]),ArbitResult.None,block.timestamp,0));
        }
        db.arbitTable.totalCardArbitCount++;
     }
     result=true;
     emit _CardArbitCreated(msg.sender,usdtAmount);
    }
    function giveCardArbitResult(string calldata arbitId,address userAddr,uint giveResult ) external {
      _checkCardGivedResult(userAddr,giveResult);
     
      uint nArbiterIndex=_findArbiterIndexForExOrder(db.arbitTable.cardArbitDetailList[userAddr],msg.sender);
      {
         require(nArbiterIndex>0,'you can not arbit this order');
         //check arbitInfo
         nArbiterIndex--;
         require(db.arbitTable.cardArbitDetailList[userAddr][nArbiterIndex].taskTime != 0,'Arbiting time has not arrived yet');
         require(db.arbitTable.cardArbitDetailList[userAddr][nArbiterIndex].result == ArbitResult.None,'arbit has been handled');
      }

      db.arbitTable.cardArbitDetailList[userAddr][nArbiterIndex].result=(giveResult==1? ArbitResult.Accuser:ArbitResult.Appellee);
      db.arbitTable.cardArbitDetailList[userAddr][nArbiterIndex].handleTime=block.timestamp;

      _updateCardArbitResult(userAddr);

       emit _CardArbitResultGived(msg.sender,userAddr,giveResult);
    }
    function _checkCardGivedResult(address userAddr,uint giveResult) internal pure {
     require(giveResult>0 && giveResult<3,'result error');
    }
    function queryCardArbitResult(address userAddr) external view returns(uint result,uint AccuserCount,uint AppelleeCount){
     if(db.arbitTable.carArbitList[userAddr].lastApplyTime>0 && db.arbitTable.carArbitList[userAddr].state!=ArbitState.None){
         (AccuserCount,AppelleeCount)=_queryResultCount(db.arbitTable.cardArbitDetailList[userAddr]);
         result=uint(db.arbitTable.carArbitList[userAddr].arbitResult);
     }
    }
    function updateCardArbitResult(address userAddr) external returns(uint result,uint AccuserCount,uint AppelleeCount){
     if(db.arbitTable.carArbitList[userAddr].lastApplyTime>0 && db.arbitTable.carArbitList[userAddr].state!=ArbitState.None){
         if(db.arbitTable.carArbitList[userAddr].state!=ArbitState.Completed){
            (AccuserCount,AppelleeCount)=_updateCardArbitResult(userAddr);
         }else{
            (AccuserCount,AppelleeCount)=_queryResultCount(db.arbitTable.cardArbitDetailList[userAddr]);
         }
         result=uint(db.arbitTable.carArbitList[userAddr].arbitResult);
     }
    }
    function queryCardArbitState(address userAddr) external view returns(uint){
       return uint(db.arbitTable.carArbitList[userAddr].state);
    }
    function queryCardArbitList(address userAddr) external view returns(ArbitInfo[] memory){
       return db.arbitTable.cardArbitDetailList[userAddr];
    }
    function _updateCardArbitResult(address userAddr) internal returns(uint AccuserCount,uint AppelleeCount) {
      (AccuserCount,AppelleeCount)=_queryResultCount(db.arbitTable.cardArbitDetailList[userAddr]);
      if(AccuserCount>=(consts.arbitParam.nArbitNum/2+1)){
         db.arbitTable.carArbitList[userAddr].arbitResult=ArbitResult.Accuser;
      }else if(AppelleeCount>=(consts.arbitParam.nArbitNum/2+1)){
         db.arbitTable.carArbitList[userAddr].arbitResult=ArbitResult.Appellee;
      }
      uint nTotal=AccuserCount.add(AppelleeCount);
      if(((block.timestamp-db.arbitTable.carArbitList[userAddr].lastApplyTime)>=nArbitTimePeriod || nTotal>=consts.arbitParam.nArbitNum) && db.arbitTable.carArbitList[userAddr].state!=ArbitState.Completed){
          //仲裁结束
          //如果未获得多数支持，则为失败
          if(db.arbitTable.carArbitList[userAddr].arbitResult!=ArbitResult.Accuser){
             db.arbitTable.carArbitList[userAddr].arbitResult=ArbitResult.Appellee;
          }
          db.arbitTable.carArbitList[userAddr].lastCompleteTime=block.timestamp;
          db.arbitTable.carArbitList[userAddr].state=ArbitState.Completed;
         
          if(db.arbitTable.totalCardArbitCount>0){
             db.arbitTable.totalCardArbitCount--;
          }
          //结算，封卡仲裁
          _settleCardArbitAssets(userAddr,db.arbitTable.carArbitList[userAddr].arbitResult,AccuserCount,AppelleeCount);
      }
      emit _CardArbitResultUpdated(msg.sender,userAddr,AccuserCount,AppelleeCount);
    }
    function _settleCardArbitAssets(address userAddr,ArbitResult arbitResult,uint AccuserCount,uint AppelleeCount) internal{
     uint winnerCount=0;
     if(arbitResult == ArbitResult.Accuser){
        winnerCount=AccuserCount;
        uint dotcAmount=_getDOTCNumFromUSDT( db.arbitTable.carArbitList[msg.sender].applyUSDTAmount);
        require(db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply>=dotcAmount,'insufficient risk pool supply');
        db.userTable.userAssets[userAddr][db.config.dotcContract].available=db.userTable.userAssets[userAddr][db.config.dotcContract].available.add(dotcAmount);
     }
     else if(arbitResult == ArbitResult.Appellee){
        winnerCount=AppelleeCount;
     }
     else{
        return;
     }
     //reward arbiter
     _rewardDOTCToArbiter(db.arbitTable.cardArbitDetailList[userAddr],db.arbitTable.carArbitList[userAddr].lockedDotcAmount,winnerCount,arbitResult);
    }
    function cancelCardArbit() external returns(bool result){
       _checkCancelCardArbit();
       //取消封卡仲裁
       db.arbitTable.carArbitList[msg.sender].state=ArbitState.Cancelled;
       db.arbitTable.carArbitList[msg.sender].lastCompleteTime=block.timestamp;
       db.arbitTable.carArbitList[msg.sender].lastApplyTime=0;
       if(db.arbitTable.carArbitList[msg.sender].lockedDotcAmount>0){
          //返回锁仓的DOTC仲裁费
           _unLockToken(msg.sender,db.config.dotcContract,db.arbitTable.carArbitList[msg.sender].lockedDotcAmount);
           db.arbitTable.carArbitList[msg.sender].lockedDotcAmount=0;
       }
       //删除分配的仲裁员信息
       delete db.arbitTable.cardArbitDetailList[msg.sender];
       if(db.arbitTable.totalCardArbitCount>0){
          db.arbitTable.totalCardArbitCount--;
       }
       result=true;
       emit _CardArbitCancelled(msg.sender);
    }
    function _checkCancelCardArbit() internal view{
       require(db.arbitTable.carArbitList[msg.sender].state==ArbitState.Dealing,'arbit state can only be dealing');
       (uint AccuserCount,uint AppelleeCount)=_queryResultCount(db.arbitTable.cardArbitDetailList[msg.sender]);
       require(AccuserCount<=0 && AppelleeCount<=0,'some arbiters have gived result.');
    }
  
}