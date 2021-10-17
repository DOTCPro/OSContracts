// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../facetBase/DOTCFacetBase.sol";

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";
import '../utils/SafeMath.sol';
import '../libraries/LibStrings.sol';

contract DOTCExOrderFacet is DOTCFacetBase {
    using SafeMath for uint;
    event _ExOrderCreated(string adOrderId,string exOrderId,uint amount);
    event _ExOrderCancelled(string adOrderId,string exOrderId);

    event _AdOrderPayed(string orderId);
    event _AdOrderReceived(string orderId);
    function createExOrder(string calldata adOrderId,string calldata exOrderId,uint amount) external returns (bool result) {
      _checkExOrder(adOrderId,exOrderId,amount);
      {
        db.orderTable.otcAdOrders[adOrderId].detail.leftAmount=db.orderTable.otcAdOrders[adOrderId].detail.leftAmount.sub(amount);
        db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount=db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount.add(amount);
      }
      uint256 nOrderValue=db.orderTable.otcAdOrders[adOrderId].depositInfo.orderValue.mul(amount).div(db.orderTable.otcAdOrders[adOrderId].detail.totalAmount);
      require(nOrderValue>=20*nUsdtDecimals,'AdOrder value must be greater than 20 USDT.');
      uint256 dotcAmount=db.orderTable.otcAdOrders[adOrderId].depositInfo.dotcAmount.mul(amount).div(db.orderTable.otcAdOrders[adOrderId].detail.totalAmount);
      ExchangeSide myside=(db.orderTable.otcAdOrders[adOrderId].side==ExchangeSide.BUY?ExchangeSide.SELL:ExchangeSide.BUY);
      _updateExAsset(dotcAmount,amount,db.orderTable.otcAdOrders[adOrderId].tokenA,myside);
      //lock fee
      _lockExOrderFee(adOrderId,exOrderId,dotcAmount,db.orderTable.otcAdOrders[adOrderId].tokenA,myside,nOrderValue);
      //add trade order
      _addExOrder(adOrderId,exOrderId,amount,myside,nOrderValue,dotcAmount);
      result=true;
      emit _ExOrderCreated(adOrderId,exOrderId,amount);
    }

    function queryExOrderDeposit(string calldata adOrderId,string calldata exOrderId,uint amount) external view returns(uint nOrderValue,uint dotcAmount){
      nOrderValue=db.orderTable.otcAdOrders[adOrderId].depositInfo.orderValue.mul(amount).div(db.orderTable.otcAdOrders[adOrderId].detail.totalAmount);
      dotcAmount=db.orderTable.otcAdOrders[adOrderId].depositInfo.dotcAmount.mul(amount).div(db.orderTable.otcAdOrders[adOrderId].detail.totalAmount);
      if(db.orderTable.otcAdOrders[adOrderId].side==ExchangeSide.BUY){
        dotcAmount=dotcAmount.mul(10).div(100);
      }
    }

    function _checkExOrder(string memory adOrderId,string memory exOrderId,uint amount) internal view {
      require(db.orderTable.otcAdOrders[adOrderId].makerAddress !=address(0),'AdOrder not exists');
      require(db.orderTable.otcAdOrders[adOrderId].state == OrderState.ONTRADE,'AdOrder has been closed');
      require(db.orderTable.otcAdOrders[adOrderId].makerAddress != msg.sender,'you can not trade with yourself');
      require(db.orderTable.otcAdOrders[adOrderId].detail.leftAmount>=amount,'insufficient left amount');
      require(amount <= db.orderTable.otcAdOrders[adOrderId].detail.maxAmount,"amount must be less than maxAmount");
      require(amount >= db.orderTable.otcAdOrders[adOrderId].detail.minAmount,"amount must be greater than minAmount");
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress==address(0),'trade has been exists');

    }

    function _updateExAsset(uint dotcAmount,uint amount,address tokenA,ExchangeSide myside) internal {
      if(myside==ExchangeSide.BUY){
        _lockToken(msg.sender,db.config.dotcContract,dotcAmount);
      }else{
        _lockToken(msg.sender,db.config.dotcContract,dotcAmount.mul(10).div(100));
        _lockToken(msg.sender,tokenA,amount);
      }
    }

    function _lockExOrderFee(string memory adOrderId,string memory exOrderId,uint dotcAmount,address tokenA,ExchangeSide myside,uint nExOrderValue) internal {
      if(db.config.takerFee>0 && myside==ExchangeSide.SELL){
          //卖单，需要提前扣除手续费
          FeeInfo memory feeInfo=_calculateOrderFee(tokenA,db.config.takerFee,nExOrderValue,dotcAmount,true);
          if(feeInfo.feeValue>0){
            if(feeInfo.feeType==CoinType.USDT){
              //usdt trade--lock fee
              _lockToken(msg.sender,db.config.usdtContract,feeInfo.feeValue);
              db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeValue=feeInfo.feeValue;
              db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeType=CoinType.USDT;
            }else if(feeInfo.feeType==CoinType.DOTC){
              //non-usdt trade
              //lock dotc fee
              _lockToken(msg.sender,db.config.dotcContract,feeInfo.feeValue);
              db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeValue=feeInfo.feeValue;
              db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeType=CoinType.DOTC;
            }
          }

        }
    }

    function _addExOrder(string memory adOrderId,string memory exOrderId,uint amount,ExchangeSide myside,uint nOrderValue,uint dotcAmount) internal{
        {
          db.orderTable.otcTradeOrders[adOrderId][exOrderId]._exOrderId=exOrderId;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId]._adOrderId=adOrderId;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress=db.orderTable.otcAdOrders[adOrderId].makerAddress;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress=msg.sender;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].side=myside;
        }
        {
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenA=db.orderTable.otcAdOrders[adOrderId].tokenA;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenB=db.orderTable.otcAdOrders[adOrderId].tokenB;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount=amount;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeTime=block.timestamp;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state=TradeState.Filled;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.lastUpdateTime=block.timestamp;

          db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.orderValue=nOrderValue;
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount=dotcAmount;
          //add to map
          db.orderTable.otcExAdMap[exOrderId]=adOrderId;
          db.orderTable.otcAdOrderCounter[adOrderId].push(exOrderId);
        }
    }

   function cancelExOrder(string memory adOrderId,string memory exOrderId) external returns(bool result){
     _checkCancelExOrder(adOrderId,exOrderId);
     {
        uint amount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount;
        db.orderTable.otcAdOrders[adOrderId].detail.leftAmount=db.orderTable.otcAdOrders[adOrderId].detail.leftAmount.add(amount);
        db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount=db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount.sub(amount);
     }
     //释放双方已锁定的代币和保证金
     _unLockCancelAssets(adOrderId,exOrderId);
     //更新订单状态
     db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state=TradeState.Cancelled;
     db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.lastUpdateTime=block.timestamp;
     //更新订单map
     delete db.orderTable.otcExAdMap[exOrderId];
     _RemoveExOrderFromList(adOrderId,exOrderId);

     result=true;
     emit _ExOrderCancelled(adOrderId,exOrderId);
   }

   function _checkCancelExOrder(string memory adOrderId,string memory exOrderId) internal view {
      require(db.orderTable.otcAdOrders[adOrderId].makerAddress !=address(0),'AdOrder not exists');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress!=address(0),'ExOrder not exists');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress==msg.sender,'You do not have permission to cancel');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state==TradeState.Filled,'ExOrder can not be cancelled now');
   }

   function _unLockCancelAssets(string memory adOrderId,string memory exOrderId) internal{
      //解锁订单资产
      {
        uint dotcAmount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount;

        if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].side==ExchangeSide.BUY){
          //订单买单
          _unLockToken(msg.sender,db.config.dotcContract,dotcAmount);
        }else{
          //订单卖单
          _unLockToken(msg.sender,db.config.dotcContract,dotcAmount.mul(10).div(100));
          _unLockToken(msg.sender,db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenA,db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount);
          _backSELLExOrderFee(adOrderId,exOrderId);
        }
      }
   }

    function _backSELLExOrderFee(string memory adOrderId,string memory exOrderId) internal {
       if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeValue<=0) return;
       if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].side==ExchangeSide.BUY) return;
       if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeType==CoinType.USDT){
         _unLockToken(db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress,db.config.usdtContract,db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeValue);
       }else if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeType==CoinType.DOTC){
         _unLockToken(db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress,db.config.dotcContract,db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeValue);
       }
    }

    function queryMultiExOrderStatus(string[] calldata exOrderIds) external view returns(uint[] memory states){
      require(exOrderIds.length>0,'orderIds must be greater than 0');
      require(exOrderIds.length<=100,'orderIds must be less than 101');
      states=new uint[](exOrderIds.length);
      for(uint i=0;i<exOrderIds.length;i++){
        string memory adOrderId=db.orderTable.otcExAdMap[exOrderIds[i]];
        states[i]=uint(db.orderTable.otcTradeOrders[adOrderId][exOrderIds[i]].detail.state);
      }

    }

    function queryExOrderStatus(string calldata adOrderId,string calldata exOrderId) external view returns(uint state){
      state=uint(db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state);
    }

    function queryExOrderInfo(string calldata exOrderId) external view returns(ExOrder memory exOrder){
      string memory adOrderId=db.orderTable.otcExAdMap[exOrderId];
      exOrder=db.orderTable.otcTradeOrders[adOrderId][exOrderId];
    }
    function confirmMoneyPayed(string calldata adOrderId,string calldata exOrderId) external returns (bool result) {
      require(db.orderTable.otcAdOrders[adOrderId].makerAddress !=address(0),'AdOrder not exists');
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress !=address(0),'Trade Order not exists');
        //check exorder state
      require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state==TradeState.Filled,'Trade order state can only be filled');
      //check user is valid
      if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].side==ExchangeSide.BUY){
         require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress == msg.sender,'no access');
      }
      else{
         require(db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress == msg.sender,'no access');
      }

      db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state=TradeState.MoneyPayed;
      db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.lastUpdateTime=block.timestamp;
      result=true;
      emit _AdOrderPayed(exOrderId);
    }

    function getTradeParam() external view returns(uint takerFee,uint makerFee,uint backRate,uint price){
      takerFee=db.config.takerFee;
      makerFee=db.config.makerFee;
      backRate=_getBackRate(); //1:0.7
      price=_getPubDOTCPrice();
    }
    function _OrderCompleted(string calldata adOrderId,string calldata exOrderId)  internal{
      db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.state=TradeState.Completed;
      db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.lastUpdateTime=block.timestamp;
      //clear deposit
      _ClearOrderDeposit(adOrderId,exOrderId);
      //检查是否关闭广告
      _checkCloseAdOrder(adOrderId);
      //更新订单状态
      _RemoveExOrderFromList(adOrderId,exOrderId);

    }
    function _ClearOrderDeposit(string calldata adOrderId,string calldata exOrderId) internal {
      address buyerAddr;
      address sellerAddr;
      FeeInfo memory buyFee;
      FeeInfo memory sellFee;
      if(db.orderTable.otcTradeOrders[adOrderId][exOrderId].side==ExchangeSide.BUY){
        buyerAddr = db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress;
        sellerAddr = db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress;
        buyFee=_GetOrderFeeValue(adOrderId,exOrderId,1);
        sellFee=_GetAdSellMakerFeeValue(adOrderId,exOrderId); //广告订单为卖单
      }else{
        buyerAddr = db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress;
        sellerAddr = db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress;
        buyFee=_GetOrderFeeValue(adOrderId,exOrderId,0);
        sellFee=_GetExSellTakerFeeValue(adOrderId,exOrderId); //交易订单为卖单
      }
      //归还买家保证金
      _clearExOrderAssets(adOrderId,exOrderId,buyerAddr,sellerAddr,buyFee,sellFee);
      //交易历史统计
      db.orderTable.otcTradeStatistics[db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress][db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress]++;
    }
    function _GetOrderFeeValue(string memory adOrderId,string memory exOrderId,uint tradeType) internal view returns(FeeInfo memory feeInfo){
       uint feeRate=0;
       if(tradeType==0){
         feeRate=db.config.makerFee;
       }else{
         feeRate=db.config.takerFee;
       }
       if(feeRate>0){
          feeInfo=_calculateOrderFee(db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenA,
          feeRate,
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.orderValue,
          db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount,
          true
         );
        }
    }
    function _GetAdSellMakerFeeValue(string memory adOrderId,string memory exOrderId) internal view returns(FeeInfo memory feeInfo){
      if(db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue<=0) return feeInfo;
      feeInfo.feeValue=db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount.mul(db.orderTable.otcAdOrders[adOrderId].depositInfo.feeValue)
           .div(db.orderTable.otcAdOrders[adOrderId].detail.totalAmount);
      feeInfo.feeType=db.orderTable.otcAdOrders[adOrderId].depositInfo.feeType;
    }
    function _GetExSellTakerFeeValue(string memory adOrderId,string memory exOrderId) internal view returns(FeeInfo memory feeInfo){
       feeInfo.feeValue=db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeValue;
       feeInfo.feeType=db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.feeType;
    }
    function _clearExOrderAssets(string calldata adOrderId,string calldata exOrderId,address buyerAddr,address sellerAddr,FeeInfo memory buyFee,FeeInfo memory sellFee) internal{
      uint dotcAmount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].depositInfo.dotcAmount;
      uint tradeAmount=db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tradeAmount;
      address tokenA=db.orderTable.otcTradeOrders[adOrderId][exOrderId].detail.tokenA;
      uint nHistoryTradeTimes=db.orderTable.otcTradeStatistics[db.orderTable.otcTradeOrders[adOrderId][exOrderId].takerAddress][db.orderTable.otcTradeOrders[adOrderId][exOrderId].makerAddress];
      if(tokenA == db.config.usdtContract){
        //原路退回DOTC保证金
        _unLockToken(buyerAddr,db.config.dotcContract,dotcAmount);
        _unLockToken(sellerAddr,db.config.dotcContract,dotcAmount.mul(10).div(100));
        //从交易数量中扣除USDT
        //退回交易币种
        db.userTable.userAssets[sellerAddr][tokenA].locked=db.userTable.userAssets[sellerAddr][tokenA].locked.sub(tradeAmount);
        db.userTable.userAssets[sellerAddr][db.config.usdtContract].locked=db.userTable.userAssets[sellerAddr][db.config.usdtContract].locked.sub(sellFee.feeValue);
        //T+N提币
        _addUnlockedAmount(buyerAddr,tokenA,tradeAmount.sub(buyFee.feeValue),nHistoryTradeTimes>0?nOtherTradeLockTime:nFirstTradeLockTime);
        //db.userTable.userAssets[buyerAddr][tokenA].available=db.userTable.userAssets[buyerAddr][tokenA].available.add(tradeAmount.sub(buyFee.feeValue));
         //USDT交易挖矿
        _RewardTradeMining(buyerAddr,buyFee);
        _RewardTradeMining(sellerAddr,sellFee);
        //USDT手续费转入Staking池
        _transferFeeToStakingPool(buyFee);
        _transferFeeToStakingPool(sellFee);
      }else{
        //退回保证金
        _backOrderToken(buyerAddr,db.config.dotcContract,dotcAmount,buyFee); //含扣除的手续费
        _backOrderToken(sellerAddr,db.config.dotcContract,dotcAmount.mul(10).div(100).add(sellFee.feeValue),sellFee);
        //退回交易币种
        //db.userTable.userAssets[sellerAddr][db.config.dotcContract].locked=db.userTable.userAssets[sellerAddr][db.config.dotcContract].locked.sub(sellFee.feeValue);
        db.userTable.userAssets[sellerAddr][tokenA].locked=db.userTable.userAssets[sellerAddr][tokenA].locked.sub(tradeAmount);
        //T+N提币
         _addUnlockedAmount(buyerAddr,tokenA,tradeAmount,nHistoryTradeTimes>0?nOtherTradeLockTime:nFirstTradeLockTime);
        //db.userTable.userAssets[buyerAddr][tokenA].available=db.userTable.userAssets[buyerAddr][tokenA].available.add(tradeAmount);
      }
    }
    function _transferFeeToStakingPool(FeeInfo memory feeInfo) internal{
      //staking pool
      if(feeInfo.feeValue<=0 || feeInfo.feeType!=CoinType.USDT) return;
      db.stakingTable.poolA[db.config.dotcContract].totalUSDTBonus=db.stakingTable.poolA[db.config.dotcContract].totalUSDTBonus.add(feeInfo.feeValue.div(2));
      db.stakingTable.poolB[db.config.dotcContract].totalUSDTBonus=db.stakingTable.poolB[db.config.dotcContract].totalUSDTBonus.add(feeInfo.feeValue.div(2));
    }
    function _backOrderToken(address userAddr,address token,uint unLockAmount,FeeInfo memory feeInfo) internal {
      require(db.userTable.userAssets[userAddr][token].locked >= unLockAmount,"insufficient locked balance");
      db.userTable.userAssets[userAddr][token].available=db.userTable.userAssets[userAddr][token].available.add(unLockAmount.sub(feeInfo.feeValue));
      db.userTable.userAssets[userAddr][token].locked=db.userTable.userAssets[userAddr][token].locked.sub(unLockAmount);
      if(feeInfo.feeType==CoinType.DOTC){
         db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply=db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply.add(feeInfo.feeValue);
      }
    }
    /*
    **交易挖矿奖励DOTC及二级邀请人
    */
    function _RewardTradeMining(address userAddr,FeeInfo memory feeInfo) internal {
      if(feeInfo.feeType!=CoinType.USDT) return;
      uint dotcAmount=_getDOTCNumFromUSDT(feeInfo.feeValue);
      uint backRate=_getBackRate();
      dotcAmount=dotcAmount.mul(backRate).div(1000);
      if(dotcAmount<=0) return;
      //判断交易挖矿矿池余额是否足额
      uint nTotalMined=dotcAmount.mul(110).div(100);
      if(db.daoData.miningPool.poolTokens[db.config.dotcContract].currentSupply<nTotalMined){
        //余额不足，则不执行交易挖矿
        return;
      }
      //reward
      {
        nTotalMined=dotcAmount;
        db.userTable.userAssets[userAddr][db.config.dotcContract].available=db.userTable.userAssets[userAddr][db.config.dotcContract].available.add(dotcAmount);
        address invitor=db.userTable.userInviteList[userAddr];
        if(invitor!=address(0)){
          db.userTable.userAssets[invitor][db.config.dotcContract].available=db.userTable.userAssets[invitor][db.config.dotcContract].available.add(dotcAmount.mul(5).div(100));
          nTotalMined=nTotalMined.add(dotcAmount.mul(5).div(100));
        }
        address invitorLast=db.userTable.userInviteList[invitor];
        if(invitorLast!=address(0)){
          db.userTable.userAssets[invitorLast][db.config.dotcContract].available=db.userTable.userAssets[invitorLast][db.config.dotcContract].available.add(dotcAmount.mul(5).div(100));
          nTotalMined=nTotalMined.add(dotcAmount.mul(5).div(100));
        }
      }

      //update pool
      _updateMingPool(nTotalMined);
    }

    function _updateMingPool(uint newAmount) internal {
      db.daoData.miningPool.poolTokens[db.config.dotcContract].periodMined=db.daoData.miningPool.poolTokens[db.config.dotcContract].periodMined.add(newAmount);
      db.daoData.miningPool.poolTokens[db.config.dotcContract].totalMined=db.daoData.miningPool.poolTokens[db.config.dotcContract].totalMined.add(newAmount);
      if(db.daoData.miningPool.poolTokens[db.config.dotcContract].periodMined>=(1360000 * nDOTCDecimals)){
        db.daoData.miningPool.poolTokens[db.config.dotcContract].periodCount++;
        db.daoData.miningPool.poolTokens[db.config.dotcContract].periodMined=0;
      }
    }

    function _checkCloseAdOrder(string memory adOrderId) internal{
      if(db.orderTable.otcAdOrders[adOrderId].detail.leftAmount<=0 &&db.orderTable.otcAdOrders[adOrderId].detail.lockedAmount<=0){
        //订单全部成交，自动关闭订单
         db.orderTable.otcAdOrders[adOrderId].state=OrderState.CLOSED;

         if(db.orderTable.orderCount>0){
           db.orderTable.orderCount--;
         }
      }
    }

}
