// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../facetBase/DOTCFacetBase.sol";

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";
import '../utils/SafeMath.sol';

contract DOTCAdOrderFacet is DOTCFacetBase {
    using SafeMath for uint;
    event _AdOrderCreated(string orderId,address makerAddr);
    event _AdOrderClosed(string orderId);

    uint nPriceDecimals=10000;

    struct AdInput{
      string orderId;
      uint side;
      address tokenA;
      address tokenB;
      uint price;
      uint totalAmount;
      uint minAmount;
      uint maxAmount;
    }
     //Create a otcOrder
    function createAdOrder(AdInput memory  adInput) external returns (bool result) {
      //check data
      _checkAdOrder(adInput);
      (uint nOrderValue,uint dotcAmount)=_queryAdDeposit(adInput);
      require(dotcAmount > 0,'invalid order deposit');
      require(nOrderValue >= 20*nUsdtDecimals,'AdOrder value must be greater than 20 USDT.');
      //update assets
      _updateAdAssets(adInput,nOrderValue,dotcAmount);
       //lock fee
      _lockAdOrderFee(adInput,nOrderValue,dotcAmount);
      //create adOrder
      _addAdOrder(adInput,nOrderValue,dotcAmount);

      result=true;
      emit _AdOrderCreated(adInput.orderId,msg.sender);
    }

    function queryAdOrderDeposit(AdInput memory  adInput) external view returns(uint orderValue,uint deposit){
       (uint nOrdrValue,uint dotcAmount)=_queryAdDeposit(adInput);
       orderValue=nOrdrValue;
       if(adInput.side==0){ //BUY
         deposit=dotcAmount;
      }else{
         deposit=dotcAmount.mul(10).div(100);
      }
    }

    function _checkAdOrder(AdInput memory  adInput) internal view {
      require(msg.sender!=address(0),"sender invalid");
      require(db.userTable.userList[msg.sender].isVIP,"only vip user can create adorder.");
      require(adInput.tokenA!=address(0),"tokenA address invalid");
      require(adInput.tokenB!=address(0),"tokenB address invalid");
      require(adInput.tokenB==db.config.usdtContract,"tokenB can only be USDT");
      require(adInput.price> 0,'price must be greater than 0');
      require(adInput.totalAmount>0,"amount invalid");
      require(adInput.minAmount>0,"minAmount invalid");
       require(adInput.minAmount>= 20*nUsdtDecimals,'AdOrder value must be greater than 20 USDT.');
      require(adInput.maxAmount>0,"maxAmount invalid");
      require(adInput.totalAmount>=adInput.maxAmount,"totalAmount must be greater than maxAmount");
      require(adInput.minAmount<=adInput.maxAmount,"maxAmount must be greater than minAmount");
      require(db.orderTable.otcAdOrders[adInput.orderId].makerAddress ==address(0),'AdOrder exists');
    }

    function _queryAdDeposit(AdInput memory  adInput) internal view returns(uint nOrderValue,uint dotcAmount){
        uint tokenADecimals= 10 ** LibERC20.queryDecimals(adInput.tokenA);
        if(adInput.tokenA==db.config.usdtContract){
          nOrderValue=adInput.totalAmount;
        }else{
          //require(consts.usdtDecimals>0,'consts.usdtDecimals must be greater than 0');
          //require(usdtDecimals>0,'usdtDecimals must be greater than 0');
          require(tokenADecimals>0,'tokenADecimals must be greater than 0');
          nOrderValue=adInput.totalAmount.div(10000).mul(nUsdtDecimals).div(tokenADecimals);
          nOrderValue=nOrderValue.mul(adInput.price);
        }
        require(nOrderValue>0,'OrderValue must be greater than 0');

        if(adInput.tokenA==db.config.dotcContract){
          dotcAmount=adInput.totalAmount;
        }else{
          //uint nDotcDecimals=10 ** consts.dotcDecimals;
          dotcAmount= nOrderValue.mul(nDOTCDecimals).div(_getPubDOTCPrice()).mul(nDOTCDecimals).div(nUsdtDecimals);
        }
    }
    function _updateAdAssets(AdInput memory  adInput,uint orderValue,uint dotcAmount) internal {
      if(adInput.side==0){
        _lockToken(msg.sender,db.config.dotcContract,dotcAmount);
      }else{
        _lockToken(msg.sender,db.config.dotcContract,dotcAmount.mul(10).div(100));
        //check user available balance
        _lockToken(msg.sender,adInput.tokenA,adInput.totalAmount);
      }
    }
    function _lockAdOrderFee(AdInput memory  adInput,uint orderValue,uint dotcAmount) internal {
      if(db.config.makerFee>0 && adInput.side==1){
          //卖单，需要提前冻结手续费
          FeeInfo memory feeInfo=_calculateOrderFee(adInput.tokenA,db.config.makerFee,orderValue,dotcAmount,false);
          if(feeInfo.feeValue>0){
             if(feeInfo.feeType==CoinType.USDT){
              //usdt trade--lock fee
              _lockToken(msg.sender,db.config.usdtContract,feeInfo.feeValue);
              db.orderTable.otcAdOrders[adInput.orderId].depositInfo.feeValue=feeInfo.feeValue;
              db.orderTable.otcAdOrders[adInput.orderId].depositInfo.feeType=CoinType.USDT;
            }else if(feeInfo.feeType==CoinType.DOTC){
              //non-usdt trade
              //lock dotc fee
              _lockToken(msg.sender,db.config.dotcContract,feeInfo.feeValue);
              db.orderTable.otcAdOrders[adInput.orderId].depositInfo.feeValue=feeInfo.feeValue;
              db.orderTable.otcAdOrders[adInput.orderId].depositInfo.feeType=CoinType.DOTC;
            }
          }

      }
    }
    function _addAdOrder(AdInput memory  adInput,uint nOrderValue,uint dotcAmount) internal {
      {
        db.orderTable.otcAdOrders[adInput.orderId].orderId=adInput.orderId;
        db.orderTable.otcAdOrders[adInput.orderId].makerAddress=msg.sender;
        db.orderTable.otcAdOrders[adInput.orderId].side=adInput.side==0?ExchangeSide.BUY:ExchangeSide.SELL;
        db.orderTable.otcAdOrders[adInput.orderId].tokenA=adInput.tokenA;
        db.orderTable.otcAdOrders[adInput.orderId].tokenB=adInput.tokenB;

        db.orderTable.otcAdOrders[adInput.orderId].detail.price=adInput.price;
        db.orderTable.otcAdOrders[adInput.orderId].detail.totalAmount=adInput.totalAmount;
        db.orderTable.otcAdOrders[adInput.orderId].detail.leftAmount=adInput.totalAmount;
        db.orderTable.otcAdOrders[adInput.orderId].detail.lockedAmount=0;
        db.orderTable.otcAdOrders[adInput.orderId].detail.minAmount=adInput.minAmount;
        db.orderTable.otcAdOrders[adInput.orderId].detail.maxAmount=adInput.maxAmount;
        db.orderTable.otcAdOrders[adInput.orderId].detail.AdTime=block.timestamp;

        db.orderTable.otcAdOrders[adInput.orderId].state=OrderState.ONTRADE;
        db.orderTable.otcAdOrders[adInput.orderId].depositInfo.orderValue=nOrderValue;
        db.orderTable.otcAdOrders[adInput.orderId].depositInfo.dotcAmount=dotcAmount;
      }
      db.orderTable.orderCount=db.orderTable.orderCount.add(1);
    }
    function checkAdOrderRemovable(string calldata orderId) external view returns (bool result){
       result=_checkAdRemovable(orderId);
    }
    function _checkAdRemovable(string calldata orderId) internal view returns (bool result){
       require(db.orderTable.otcAdOrders[orderId].makerAddress !=address(0),'AdOrder not exists');
       require(db.orderTable.otcAdOrders[orderId].state == OrderState.ONTRADE,'AdOrder has been closed');
       require(db.orderTable.otcAdOrderCounter[orderId].length <= 0,'there is non-closed trade order');
       result=true;
    }

    function queryAdOrderAvaiAmount(string calldata orderId) external view returns(uint amount){
      if(db.orderTable.otcAdOrders[orderId].state==OrderState.ONTRADE){
        amount=db.orderTable.otcAdOrders[orderId].detail.leftAmount;
      }
    }

    function existAdOrder(string calldata orderId) external view returns (bool result) {
      result=db.orderTable.otcAdOrders[orderId].state==OrderState.ONTRADE;
    }

    function getAdOrderCount() external view returns (uint) {
      return db.orderTable.orderCount;
    }

    function queryMultiAdOrdersStatus(string[] calldata orderIds) external view returns(uint[] memory states){
      require(orderIds.length>0,'orderId count must be greater than 0');
      require(orderIds.length<=100,'orderId count must be less than 101');
      states=new uint[](orderIds.length);
      for(uint i=0;i<orderIds.length;i++){
        states[i]=uint(db.orderTable.otcAdOrders[orderIds[i]].state);
      }
    }

    function queryAdOrderStatus(string calldata  orderId) external view returns(uint state){
      state=uint(db.orderTable.otcAdOrders[orderId].state);
    }

    function queryAdOrderInfo(string calldata  orderId) external view returns(AdOrder memory adOrder){
      adOrder=db.orderTable.otcAdOrders[orderId];
    }

}


