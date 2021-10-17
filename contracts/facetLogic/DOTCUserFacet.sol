// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";
import "../libraries/LibStrings.sol";

import "../facetBase/DOTCFacetBase.sol";

import '../utils/SafeMath.sol';
import '../utils/SafeArray.sol';
import '../utils/SignHelper.sol';

contract DOTCUserFacet is DOTCFacetBase {
    using SafeMath for uint; 
    using SafeArray for uint[];

    event _VIPApplied(address user,bool result); 
    event _SponsorUpdated(address sponsor,address userAddr,uint amount); 

    event _tokenDeposited(address userAddr,address token,uint amount); 
    event _tokenWithdrawed(address userAddr,address token,uint amount); 

    event _ReleaseUnlockAmount(address userAddr,address token,uint amount);
    event _ArbitApplied(address user,bool result); 
    event _ArbitCancelled(address user,bool result); 

    constructor(){

    }
    function queryUserInvitor() external view returns(address invitor){
      invitor=db.userTable.userInviteList[msg.sender];
    }
    function updateSponsorAmount(address userAddr,uint amount,string memory signature) external returns (bool result) {
      //check balance
      {
        require(userAddr!=address(0),'user address invalid.');
        require(db.userTable.userInviteList[userAddr]==address(0) || db.userTable.userInviteList[userAddr]==msg.sender,'user has been invited');
        require(db.userTable.userList[userAddr].arbitExOrderCount<=0,'user has an unclosed arbit');
      }
      {
        if(db.userTable.userInviteList[userAddr]==address(0)){
          //初次建立邀请关系,验证签名
          string memory originData='InviterAddress:';
          //originData=LibStrings.strConcat(originData,':');
          originData=LibStrings.strConcat(originData,LibStrings.addressToString(msg.sender));
          require(SignHelper.checkSign(originData,signature,userAddr),'signature invalid');
        }
      }
      uint nAddAmount=0;
      uint nSubAmount=0;
      {
        uint nCurrentAmount=db.userTable.userSponsorData[msg.sender].sponsorBalances[userAddr];
         if(nCurrentAmount>=amount){
           nSubAmount=nCurrentAmount.sub(amount);
         }else{
            nAddAmount=amount.sub(nCurrentAmount);
         }
      }
      {
        if(nAddAmount>0){
          _lockToken(msg.sender,db.config.dotcContract,nAddAmount);
          //冻结额度
          db.userTable.userSponsorData[msg.sender].sponsorBalances[userAddr]=db.userTable.userSponsorData[msg.sender].sponsorBalances[userAddr].add(nAddAmount);
          db.userTable.userSponsorData[msg.sender].totalSupply=db.userTable.userSponsorData[msg.sender].totalSupply.add(nAddAmount);
        }else if(nSubAmount>0){
           _unLockToken(msg.sender,db.config.dotcContract,nSubAmount);
          //解冻多余的额度
          db.userTable.userSponsorData[msg.sender].sponsorBalances[userAddr]=db.userTable.userSponsorData[msg.sender].sponsorBalances[userAddr].sub(nSubAmount);
          db.userTable.userSponsorData[msg.sender].totalSupply=db.userTable.userSponsorData[msg.sender].totalSupply.sub(nSubAmount);
        }
      }      
      if(db.userTable.userInviteList[userAddr]==address(0)){
          db.userTable.userInviteList[userAddr]=msg.sender;
      }

      result=true;
      emit _SponsorUpdated(msg.sender,userAddr,amount);
    } 
    function querySponsorAmount(address userAddr) external view returns(uint amount){
      amount= db.userTable.userSponsorData[msg.sender].sponsorBalances[userAddr];
    }
    //申请成为VIP
    function applyVIP() external returns (bool result) {
      UserInfo storage info=db.userTable.userList[msg.sender];
      //先检查是否已经为商家，如果为商家，则不需要锁仓保证金
      require(info.isVIP==false,'user has been vip');
      //获取账户DOTC的B类锁仓数量
      require(db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance >= consts.vipDOTC,"insufficient staking DOTC balance");
      
       if(!info.isVIP){
          //update vip state
          db.userTable.userList[msg.sender].isVIP=true;
          result=true;
      }
      emit _VIPApplied(msg.sender,result);
    }

    //查询是否为VIP
    function queryVIP(address userAddr) external view returns (bool) {
       return db.userTable.userList[userAddr].isVIP;
    }

    function tokenApproveQuery(address token) external view returns(uint256 amount){
      amount=LibERC20.approveQuery(token,address(this));
    }
    function tokenDeposit(address token,uint amount) external payable returns (bool result) {
      require(token!=address(0),'token invalid');
      require(amount>0,'amount must be greater than 0');
       //开始转账
      LibERC20.transferFrom(token, msg.sender, address(this), amount);
      db.userTable.userAssets[msg.sender][token].available=db.userTable.userAssets[msg.sender][token].available.add(amount);

      emit _tokenDeposited(msg.sender,token,amount);

      return true;
     
    } 
    function tokenWithdraw(address token,uint amount) external returns (bool) {
      require(token!=address(0),'token invalid');
      require(amount>0,'amount must be greater than 0');
       //获取账户代币余额
      uint avail=db.userTable.userAssets[msg.sender][token].available;
      require(avail>=amount,"insufficient balance");

      LibERC20.transfer(token, msg.sender, amount);

      db.userTable.userAssets[msg.sender][token].available=db.userTable.userAssets[msg.sender][token].available.sub(amount);
      emit _tokenWithdrawed(msg.sender,token,amount);

      return true;
     
    } 
    function tokenQuery(address token) external view returns (uint avail,uint locked,uint canUnlocked,uint nonUnlocked) {
      avail=db.userTable.userAssets[msg.sender][token].available;
      locked=db.userTable.userAssets[msg.sender][token].locked;
      (canUnlocked,nonUnlocked)=_queryUnlockedAmount(msg.sender,token);
    } 
    function lockToken(address token,uint lockAmount) external{
     _lockToken(msg.sender,token,lockAmount);
    }
    function queryUnlockedAmount(address token) external view returns(uint canUnlocked,uint nonUnlocked){
       (canUnlocked,nonUnlocked)=_queryUnlockedAmount(msg.sender,token);
    }
    function releaseUnlockedAmount(address token) external returns(uint canUnlocked){
       canUnlocked=_releaseUnlockedAmount(msg.sender,token);
       emit _ReleaseUnlockAmount(msg.sender,token,canUnlocked);
    }
    function applyArbiter() external returns (bool result) {
       require(!db.arbitTable.arbitUserList[msg.sender].isActive,"user has been an arbiter");
       require(db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].balance.add(db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance)>=consts.arbiterDOTC,"insufficient total staking DOTC balance");
     
       if(!db.arbitTable.arbitUserList[msg.sender].isActive){
          //update
          db.arbitTable.arbitUserList[msg.sender].isActive=true;
          db.arbitTable.arbitUserList[msg.sender].applayTime=block.timestamp;
          //add to arbiterlist
          (bool isFind,uint index)=db.arbitTable.arbiterList.Contains(uint(msg.sender));
          if(!isFind){
            db.arbitTable.arbiterList.push(uint(msg.sender));
          }
    
          return true;
      }

       result=true;
       emit _ArbitApplied(msg.sender,result);
     
    }
    function cancelArbiter() external returns (bool result) {
        require(db.arbitTable.arbitUserList[msg.sender].isActive,"user is not an arbiter");
        //update arbit state
        delete db.arbitTable.arbitUserList[msg.sender];
        db.arbitTable.arbitUserList[msg.sender].isActive=false;
        db.arbitTable.arbitUserList[msg.sender].applayTime=0;
        //db.arbitTable.arbiterList.RemoveItem(uint(msg.sender)); 
        result=true;
        emit _ArbitCancelled(msg.sender,result);
    }
    function queryArbiter(address userAddr) external view returns(bool result){
        result=db.arbitTable.arbitUserList[userAddr].isActive;
    }
    function queryArbiterHandleCount(address userAddr) external view returns(uint){
        require(db.arbitTable.arbitUserList[userAddr].isActive,'user is not an arbiter');
        return db.arbitTable.arbitUserList[userAddr].nHandleCount;
    }
    function queryArbiterListCount() external view returns(uint){
        return db.arbitTable.arbiterList.length;
    }
    function queryArbiterList() external view returns(uint[] memory){
        return db.arbitTable.arbiterList;
    }

}
