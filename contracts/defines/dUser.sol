// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;


struct UserTable{
    //userInfo List
    mapping (address => UserInfo) userList;
    //relationship
    mapping(address => address) userInviteList;
    //assets
    mapping(address => mapping (address => AssetInfo)) userAssets;
    //ASSET LockedInfo
    mapping(address => mapping (address => AssetLockInfo[])) userLockedList;
    //sponsor data
    //user address => sponsorData
    mapping(address => SponsorData) userSponsorData;
}
struct SponsorData {
    // user address => balance
    mapping(address => uint256) sponsorBalances;
    uint totalSupply;

    //exorder => balance
    mapping(string => uint256) sponsorLockList;
    uint totalLocked;
}
struct UserInfo{
    uint kycState;
    bool isVIP;
    uint arbitExOrderCount; //当前正在仲裁的交易数量
}
struct AssetLockInfo{
    uint amount;
    uint lockTime;
    bool isUnLocked;
    uint unlockDeadline;
}
struct AssetInfo{
    uint available;
    uint locked;
}