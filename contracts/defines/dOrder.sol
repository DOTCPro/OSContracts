// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

struct OrderTable{
    mapping(string => AdOrder) otcAdOrders;
    uint orderCount;

    mapping(string => mapping(string => ExOrder)) otcTradeOrders;
    mapping(string => string[]) otcAdOrderCounter; //记录当前正在交易的交易订单ID号
    mapping(string => string) otcExAdMap;
    mapping(address => mapping(address => uint)) otcTradeStatistics; //taker == mapping(maker ==> count)
}
enum ExchangeSide{
    BUY,
    SELL
}
enum OrderState{
    NONE,
    ONTRADE,
    CLOSED
}
enum TradeState{
    UnFilled,
    PartialFilled,
    Filled,
    MoneyPayed,
    MoneyReceived,
    Completed,
    ArbitClosed,
    Cancelled
}
enum CoinType{
    UNKNOWN,
    USDT,
    DOTC,
    WETH,
    OTHER
}
//OTCAdOrder Info
struct AdOrder{
    string orderId;
    address makerAddress;
    ExchangeSide side;
    address tokenA;
    address tokenB;
    OrderState state;
    AdOrderDetail detail;
    DepositInfo depositInfo;
}
struct AdOrderDetail{
    uint price;
    uint totalAmount;
    uint leftAmount;
    uint lockedAmount;
    uint minAmount;
    uint maxAmount;
    uint AdTime;
}
struct DepositInfo{
    uint orderValue;
    uint dotcAmount;
    CoinType feeType;
    uint feeValue;
}
//OTCExOrder Info
struct ExOrder{
    string _exOrderId;
    string _adOrderId;
    address makerAddress;
    address takerAddress;
    ExchangeSide side;
    ExOrderDetail detail;
    DepositInfo depositInfo;
 
}
struct ExOrderDetail{
    address tokenA;
    address tokenB;
    uint tradeAmount;
    uint tradeTime;
    TradeState state;
    uint lastUpdateTime;
}
struct FeeInfo{
    uint feeValue;
    CoinType feeType;
}



