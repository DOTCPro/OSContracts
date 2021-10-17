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


contract DOTCArbitFacet is DOTCFacetBase {
    using SafeMath for uint;
    using SafeArray for uint[];
    event _OrderArbitCreated(string adOrderId,string exOrderId,address userAddr);
    event _OrderArbitCancelled(string adOrderId,string exOrderId,address userAddr);
    event _ArbitResultGived(string adOrderId,string exOrderId,address user,uint result);
    event _OrderArbitResultUpdated(address userAddr,string exOrderId,uint AccuserCount,uint AppelleeCount);

    function createOrderArbit(string calldata adOrderId,string calldata exOrderId) external returns (bool result) {
      _checkExArbitApply(adOrderId,exOrderId);
      uint ncheckResult=_checkExArbitAccess(exOrderId);
      require(ncheckResult!=0,'you can not apply arbit now.');
      if(ncheckResult==1){
        if(consts.arbitParam.nOrderArbitCost>0){
          _lockToken(msg.sender,db.config.dotcContract,consts.arbitParam.nOrderArbitCost);
        }
        db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lockedDotcAmount=consts.arbitParam.nOrderArbitCost;
      }
      //create arbit
      {
         db.arbitTable.orderArbitList[exOrderId].adOrderId=adOrderId;
         db.arbitTable.orderArbitList[exOrderId].exOrderId=exOrderId;
         db.arbitTable.orderArbitList[exOrderId].applyUser=msg.sender;
         if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress==msg.sender){
           db.arbitTable.orderArbitList[exOrderId].appelle=db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress;
         }else{
           db.arbitTable.orderArbitList[exOrderId].appelle=db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress;
         }
         db.arbitTable.orderArbitList[exOrderId].state=ArbitState.Dealing;
         db.arbitTable.orderArbitList[exOrderId].lastApplyTime=block.timestamp;
         db.arbitTable.orderArbitList[exOrderId].arbitResult=ArbitResult.None;
         db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lastCompleteTime=0;
         db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.isSettled=false;
         db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes++;
         db.arbitTable.totalOrderArbitCount++;
         db.userTable.userList[db.arbitTable.orderArbitList[exOrderId].applyUser].arbitExOrderCount++;
         db.userTable.userList[db.arbitTable.orderArbitList[exOrderId].appelle].arbitExOrderCount++;
      }
      {
         //give arbiters
         if(consts.arbitParam.nArbitNum<nMinArbiterNum) consts.arbitParam.nArbitNum=nMinArbiterNum;
         uint[] memory arbiterList=_getRandomArbiter(consts.arbitParam.nArbitNum);
         for(uint i=0;i<arbiterList.length;i++){
            db.arbitTable.orderArbitDetailList[exOrderId].push(ArbitInfo(address(arbiterList[i]),ArbitResult.None,block.timestamp,0));
         }
      }
      emit _OrderArbitCreated(adOrderId,exOrderId,msg.sender);

      result=true;

    }
    function _checkExArbitApply(string calldata adOrderId,string calldata exOrderId) internal view{
      require(db.arbitTable.arbiterList.length>=consts.arbitParam.nArbitNum,'arbiter count is less than minimum');
      require(db.orderTable.otcAdOrders[adOrderId].makerAddress !=address(0),'AdOrder not exists');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress !=address(0),'Trade Order not exists');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress==msg.sender || db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress==msg.sender ,'no access');
      require(db.arbitTable.orderArbitList[exOrderId].state!=ArbitState.Dealing,'you have an uncompleted arbit now.');
      require(db.orderTable.otcAdOrders[adOrderId].state==OrderState.ONTRADE,'the ad order has been closed.');
      require(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes<3,'The maximum number of applications has been reached');
    }
    function queryArbitState(string calldata exOrderId) external view returns(uint){
       return uint(db.arbitTable.orderArbitList[exOrderId].state);
    }
    function cancelOrderArbit(string calldata adOrderId,string calldata exOrderId) external returns(bool result){
       _checkCancelOrderArbit(exOrderId);
       //取消仲裁
       db.arbitTable.orderArbitList[exOrderId].state=ArbitState.Cancelled;
       db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lastCompleteTime=block.timestamp;
       if(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lockedDotcAmount>0){
          //返回锁仓的DOTC仲裁费
           _unLockToken(msg.sender,db.config.dotcContract,db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lockedDotcAmount);
           db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lockedDotcAmount=0;
       }
       //删除分配的仲裁员信息
       {
          delete db.arbitTable.orderArbitDetailList[exOrderId];
          if(db.arbitTable.totalOrderArbitCount>0){
            db.arbitTable.totalOrderArbitCount--;
          }
          if(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes>0){
            db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.orderArbitTimes--;
          }
          if(db.userTable.userList[db.arbitTable.orderArbitList[exOrderId].applyUser].arbitExOrderCount>0){
            db.userTable.userList[db.arbitTable.orderArbitList[exOrderId].applyUser].arbitExOrderCount--;
          }
          if(db.userTable.userList[db.arbitTable.orderArbitList[exOrderId].appelle].arbitExOrderCount>0){
            db.userTable.userList[db.arbitTable.orderArbitList[exOrderId].appelle].arbitExOrderCount--;
          }
       }
       result=true;
       emit _OrderArbitCancelled(adOrderId,exOrderId,msg.sender);
    }
    function _checkCancelOrderArbit(string calldata exOrderId) internal view {
       require(db.arbitTable.orderArbitList[exOrderId].applyUser!=address(0),'arbit not exist');
       require(db.arbitTable.orderArbitList[exOrderId].applyUser==msg.sender,'no access');
       require(db.arbitTable.orderArbitList[exOrderId].state==ArbitState.Dealing,'arbit state can only be dealing');
       (uint AccuserCount,uint AppelleeCount)=_queryResultCount(db.arbitTable.orderArbitDetailList[exOrderId]);
       require(AccuserCount<=0 && AppelleeCount<=0,'some arbiters have gived result.');

    }
    function queryOrderArbitReward(string calldata exOrderId ) external view returns(uint nRewardAmount){
       nRewardAmount=consts.arbitParam.nOrderArbitCost;
       string memory adOrderId=db.orderTable.otcExAdMap[exOrderId];
       nRewardAmount=nRewardAmount.add(db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount.mul(10).div(100));
    }
    function giveOrderArbitResult(string calldata exOrderId,string calldata adOrderId,uint giveResult) external {
      _checkGivedResult(exOrderId,adOrderId,giveResult);

      uint nArbiterIndex=_findArbiterIndexForExOrder(db.arbitTable.orderArbitDetailList[exOrderId],msg.sender);
      {
         require(nArbiterIndex>0,'you can not arbit this order');
         //check arbitInfo
         nArbiterIndex--;
         require(db.arbitTable.orderArbitDetailList[exOrderId][nArbiterIndex].taskTime != 0,'Arbiting time has not arrived yet');
         require(db.arbitTable.orderArbitDetailList[exOrderId][nArbiterIndex].result == ArbitResult.None,'arbit has been handled');
      }

      db.arbitTable.orderArbitDetailList[exOrderId][nArbiterIndex].result=(giveResult==1? ArbitResult.Accuser:ArbitResult.Appellee);
      db.arbitTable.orderArbitDetailList[exOrderId][nArbiterIndex].handleTime=block.timestamp;
      //update result
      _updateArbitResult(exOrderId);

      emit _ArbitResultGived(adOrderId,exOrderId,msg.sender,giveResult);

    }

    function queryArbitResultCount(string calldata exOrderId) external view returns(uint result,uint AccuserCount,uint AppelleeCount){
       if(db.arbitTable.orderArbitList[exOrderId].applyUser!=address(0)){
         (AccuserCount,AppelleeCount)=_queryResultCount(db.arbitTable.orderArbitDetailList[exOrderId]);
         result=uint(db.arbitTable.orderArbitList[exOrderId].arbitResult);
       }
    }

    function updateArbitResult(string calldata exOrderId) external returns(uint result,uint AccuserCount,uint AppelleeCount){
       if(db.arbitTable.orderArbitList[exOrderId].applyUser!=address(0)){
         if(db.arbitTable.orderArbitList[exOrderId].state!=ArbitState.Completed){
            (AccuserCount,AppelleeCount)=_updateArbitResult(exOrderId);
         }else{
               (AccuserCount,AppelleeCount)=_queryResultCount(db.arbitTable.orderArbitDetailList[exOrderId]);
         }
         result=uint(db.arbitTable.orderArbitList[exOrderId].arbitResult);
       }
    }

    function queryOrderArbitList(string calldata exOrderId) external  view returns(ArbitInfo[] memory){
       return db.arbitTable.orderArbitDetailList[exOrderId];
    }

    //TODO--测试接口，待删除
    function getRandomArbiter(uint num) external view returns(uint[] memory arbiterList){
        return _getRandomArbiter(num);
    }
    function _checkGivedResult(string memory exOrderId,string memory adOrderId,uint giveResult) internal view {
      require(giveResult>0 && giveResult<3,'result error');
      //check order
      require(db.orderTable.otcAdOrders[adOrderId].makerAddress !=address(0),'AdOrder not exists');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress !=address(0),'Trade Order not exists');
      require(db.arbitTable.orderArbitList[exOrderId].state==ArbitState.Dealing,'Arbit is not processing');
    }

    function _settleArbitAssets(string memory adOrderId,string memory exOrderId) internal{
      if(db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.isSettled) return;
      if(db.arbitTable.orderArbitList[exOrderId].arbitResult == ArbitResult.None) return;
      address accUser; //胜诉方
      address appelle; //败诉方
      ExchangeSide accUserSide;
      bool isMaker=false;
      {
         if(db.arbitTable.orderArbitList[exOrderId].arbitResult==ArbitResult.Accuser){
          //原告胜诉
          accUser=db.arbitTable.orderArbitList[exOrderId].applyUser;
          appelle=db.arbitTable.orderArbitList[exOrderId].appelle;
         }else if (db.arbitTable.orderArbitList[exOrderId].arbitResult==ArbitResult.Appellee){
          //被告胜诉
          accUser=db.arbitTable.orderArbitList[exOrderId].appelle;
          appelle=db.arbitTable.orderArbitList[exOrderId].applyUser;
         }
         if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress==accUser){
            accUserSide=db.orderTable.otcTradeOrders[adOrderId][exOrderId].side;
            isMaker=false;

         }else{
            accUserSide=(db.orderTable.otcTradeOrders[adOrderId][exOrderId].side==ExchangeSide.BUY?ExchangeSide.SELL:ExchangeSide.BUY);
            isMaker=true;
         }
      }
     //清算资产
     _backWinnerDeposit(adOrderId,exOrderId,accUser,accUserSide,isMaker);
     _clearLoserDeposit(adOrderId,exOrderId,appelle,accUserSide==ExchangeSide.BUY?ExchangeSide.SELL:ExchangeSide.BUY,!isMaker);

    }
    function _backWinnerDeposit(string memory adOrderId,string memory exOrderId,address winner,ExchangeSide accUserSide,bool isMaker) internal {
      if(isMaker){
         //广告方为胜诉方
         //退回广告可用余额，保证金不动
        uint amount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount;
        db.orderTable.otcAdOrders[adOrderId].detail.leftAmount=db.orderTable.otcAdOrders[adOrderId].detail.leftAmount.add(amount);
        db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount=db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount.sub(amount);
      }else{
         //交易方为胜诉方(taker)
         uint depositAmount= db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount;
         if(accUserSide==ExchangeSide.BUY){
            _unLockToken(winner,db.config.dotcContract,depositAmount);
         }else{
            _unLockToken(winner,db.config.dotcContract,depositAmount.mul(10).div(100));
            _unLockToken(winner,db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenA,db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount);
         }
      }

    }
    function _clearLoserDeposit(string memory adOrderId,string memory exOrderId,address loser,ExchangeSide loserSide,bool isMaker) internal {
       uint tradeAmount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount;
       if(isMaker){
          //交易方为广告方
          db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount=db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount.sub(tradeAmount);
       }else{
          //交易方为败诉方
       }
       uint depositAmount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount;
       address tokenA= db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenA;
       if(loserSide==ExchangeSide.BUY){
         //扣除loser的锁定资产
         db.userTable.userAssets[loser][db.config.dotcContract].locked=db.userTable.userAssets[loser][db.config.dotcContract].locked.sub(depositAmount);
         //分3份分配
         db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply=db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply.add(depositAmount.mul(40).div(100));
         db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply=db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply.add(depositAmount.mul(50).div(100));
       }else{
         //原始币种分配
         depositAmount=depositAmount.mul(10).div(100);
         //扣除保证金
         db.userTable.userAssets[loser][db.config.dotcContract].locked=db.userTable.userAssets[loser][db.config.dotcContract].locked.sub(depositAmount);
         //扣除币种资产
         db.userTable.userAssets[loser][tokenA].locked=db.userTable.userAssets[loser][tokenA].locked.sub(tradeAmount);

         if(tokenA==db.config.dotcContract){
            //DOTC转入风控基金和交易挖矿池
            db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply=db.daoData.riskPool.poolTokens[db.config.dotcContract].currentSupply.add(tradeAmount.mul(40).div(100));
            db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply=db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply.add(tradeAmount.mul(60).div(100));
         }else if(tokenA==db.config.usdtContract){
            //USDT全部转入锁仓分红池
            db.stakingTable.poolA[db.config.usdtContract].totalUSDTBonus=db.stakingTable.poolA[db.config.usdtContract].totalUSDTBonus.add(tradeAmount);
         }else{
            //其他币种，不分配
         }
       }
       //扣除保荐人的保荐资金及保荐额度，划入交易挖矿池
       _clearInvitorSponsor(loser,depositAmount);
    }
    function _clearInvitorSponsor(address userAddr,uint dotcAmount) internal {
      address invitor=db.userTable.userInviteList[msg.sender];
      if(invitor==address(0)) return;
      uint sponsorAmount=db.userTable.userSponsorData[invitor].sponsorBalances[userAddr];
      uint nClearAmount=sponsorAmount.min(dotcAmount.mul(10).div(100));
      if(nClearAmount<=0) return;
      //扣除保荐额度
      db.userTable.userSponsorData[invitor].sponsorBalances[userAddr]= db.userTable.userSponsorData[invitor].sponsorBalances[userAddr].sub(nClearAmount);
      db.userTable.userSponsorData[invitor].totalSupply=db.userTable.userSponsorData[invitor].totalSupply.sub(nClearAmount);
      if(db.userTable.userAssets[userAddr][db.config.dotcContract].locked >= nClearAmount){
        db.userTable.userAssets[userAddr][db.config.dotcContract].locked=db.userTable.userAssets[userAddr][db.config.dotcContract].locked.sub(nClearAmount);
      }
    }
    function _rewardArbiter(string memory adOrderId,string memory exOrderId,uint winnerCount) internal {
     if(db.arbitTable.orderArbitList[exOrderId].arbitResult==ArbitResult.None) return;
     uint nRewardAmount=db.arbitTable.orderArbitList[exOrderId].arbitBackInfo.lockedDotcAmount;
     nRewardAmount=nRewardAmount.add(db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount.mul(10).div(100));
     _rewardDOTCToArbiter(db.arbitTable.orderArbitDetailList[exOrderId],nRewardAmount,winnerCount,db.arbitTable.orderArbitList[exOrderId].arbitResult);
    }

}
