// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

struct ArbitTable{
    //arbit users
    mapping(address => ArbitUserInfo ) arbitUserList;
    uint[] arbiterList;
    //arbitOrder
    mapping(string => ExOrderArbit ) orderArbitList;
    //aribit result
    mapping(string => ArbitInfo[]) orderArbitDetailList;
    mapping(string => uint)  orderArbitCount;
    uint totalOrderArbitCount;
    //card arbit
    mapping(address => CardArbit) carArbitList;
    //card arbit result
    mapping(address => ArbitInfo[]) cardArbitDetailList;
    uint  totalCardArbitCount;
    //tokens from arbit assets
    mapping(address => uint) arbitGivedToken;
}
//arbit record
enum ArbitState{
    None,
    Dealing,
    Completed,
    Cancelled
}
enum ArbitResult{
    None,
    Accuser,
    Appellee
}
struct ExOrderArbit{
    string adOrderId;
    string exOrderId;
    address applyUser;
    address appelle;
    ArbitState state;  
    ArbitResult arbitResult;
    uint lastApplyTime;
    ArbitBackInfo arbitBackInfo;
}
struct ArbitBackInfo{
    uint orderArbitTimes;
    uint lastCompleteTime;
    uint lockedDotcAmount;   
    bool isSettled;
    uint settleTime;
}
struct ArbitInfo{
    address arbiter;
    ArbitResult result;
    uint taskTime;  
    uint handleTime;
}
struct ArbitUserInfo{
    bool isActive;
    uint applayTime;
    address lockedToken;
    uint lockedAmount;
    uint nHandleCount;
}
struct CardArbit{
   uint applyUSDTAmount;
   ArbitState state;
   ArbitResult arbitResult;
   string arbitID;
   uint lastApplyTime;
   uint lastCompleteTime;
  
   uint cardArbitTimes;
   uint totalGivedUSDT;
   uint lockedDotcAmount;
}