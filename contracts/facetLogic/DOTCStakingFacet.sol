// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;
import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";

import "../facetBase/DOTCFacetBase.sol";

import '../utils/SafeMath.sol';
import '../utils/SafeArray.sol';

contract DOTCStakingFacet is DOTCFacetBase {
    using SafeMath for uint;
    using SafeArray for uint[];

    uint public constant nPoolMax=10000000;

    uint public constant nPoolAMaxDays=720 days;

    event _stakingAAdded(address userAddr,address token,uint amount);
    event _stakingBAdded(address userAddr,address token,uint amount);
    event _stakingUnlocked(address userAddr,address token,uint amount);
    event _stakingBonused(address userAddr,address token,uint amount);
    event _stakingDeposited(address userAddr,address token,uint amount);


    function AddUSDTBonusToStaking(uint lockType,uint amount) external returns(bool result){
       require(amount>0,'amount must be greater than 0');
       uint balance= IERC20(db.config.usdtContract).balanceOf(msg.sender);
       require(balance>=amount,'insufficient token balance');
       LibDiamond.enforceIsContractManager();
       //开始转账
       LibERC20.transferFrom(db.config.usdtContract, msg.sender, address(this), amount);
       if(lockType==0){
         db.stakingTable.poolA[db.config.dotcContract].totalUSDTBonus=db.stakingTable.poolA[db.config.dotcContract].totalUSDTBonus.add(amount);
       }else{
         db.stakingTable.poolB[db.config.dotcContract].totalUSDTBonus=db.stakingTable.poolB[db.config.dotcContract].totalUSDTBonus.add(amount);
       }
       emit _stakingDeposited(msg.sender,db.config.usdtContract,amount);

       result=true;
    }
    function addStakingA(uint amount) external returns (bool result) {
       {
          require(db.stakingTable.startTime>0 && db.stakingTable.startTime<=block.timestamp,'staking is not open yet');
          require(db.stakingTable.isEnableLock,'staking lock is disabled');
          require(db.stakingTable.poolA[db.config.dotcContract].totalAccount<=nPoolMax,"Pool accounts have been the maximum");
          require(amount>=consts.stakingParam.poolAMin,'amount must be greater than 100 DOTC');
          require(db.userTable.userAssets[msg.sender][db.config.dotcContract].available>=amount,"insufficient available balance");
       }
       //update
       db.userTable.userAssets[msg.sender][db.config.dotcContract].available=db.userTable.userAssets[msg.sender][db.config.dotcContract].available.sub(amount);
       //recalculate weight
       uint balance=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].balance;
       {
        if(balance==0){
          db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].weightTime=block.timestamp;
          db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].lastBonusTime=0;
          db.stakingTable.poolA[db.config.dotcContract].totalAccount+=1;
        }
        else{
          StakingDetail memory detail=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender];
          db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].weightTime=_RecalculateWeightTime(detail.balance,detail.weightTime,amount);
        }
        db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].lastLockTime=block.timestamp;
       }
       db.stakingTable.poolA[db.config.dotcContract].totalSupply=db.stakingTable.poolA[db.config.dotcContract].totalSupply.add(amount);
       db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].balance=balance.add(amount);
       result=true;

       emit _stakingAAdded(msg.sender,db.config.dotcContract,amount);
    }
    function addStakingB(uint amount) external returns (bool result) {
       {
          require(db.stakingTable.startTime>0 && db.stakingTable.startTime<=block.timestamp,'staking is not open yet');
          require(db.stakingTable.isEnableLock,'staking lock is disabled');
          require(db.stakingTable.poolB[db.config.dotcContract].totalAccount<=nPoolMax,"Pool accounts have been the maximum");
          require(amount>=consts.stakingParam.poolBMin,'amount must be greater than 10 DOTC');
          require(db.userTable.userAssets[msg.sender][db.config.dotcContract].available>=amount,"insufficient available balance");
       }
       //update
       db.userTable.userAssets[msg.sender][db.config.dotcContract].available=db.userTable.userAssets[msg.sender][db.config.dotcContract].available.sub(amount);
       //recalculate weight
       uint balance=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance;
       {
          if(balance==0){
            db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].weightTime=block.timestamp;
            db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].lastBonusTime=0;
            db.stakingTable.poolB[db.config.dotcContract].totalAccount+=1;
          }
          else{
            StakingDetail memory detail=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender];
            db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].weightTime=_RecalculateWeightTime(detail.balance,detail.weightTime,amount);
          }
          db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].lastLockTime=block.timestamp;
       }
       db.stakingTable.poolB[db.config.dotcContract].totalSupply=db.stakingTable.poolB[db.config.dotcContract].totalSupply.add(amount);
       db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance=balance.add(amount);

       result=true;

      emit _stakingBAdded(msg.sender,db.config.dotcContract,amount);
    }

    function queryAvailBonus(uint lockType) external view returns(uint availBonus,uint tatalBonus,uint lastBonusTime){
       if(lockType==0){
         //PoolA
         availBonus=_calculateAvailBonus(db.stakingTable.poolA[db.config.dotcContract],db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].balance);
         tatalBonus=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].totalBonused;
         lastBonusTime=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].lastBonusTime;
       }else{
         //PoolB
         availBonus=_calculateAvailBonus(db.stakingTable.poolB[db.config.dotcContract],db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance);
         tatalBonus=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].totalBonused;
         lastBonusTime=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].lastBonusTime;
       }

    }
    function queryLockAAmount() external view returns(uint balance,uint lastLockTime,uint weightTime){
      balance=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].balance;
      lastLockTime=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].lastLockTime;
      weightTime=db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].weightTime;
    }
    function queryLockBAmount() external view returns(uint balance,uint lastLockTime,uint weightTime){
      balance=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance;
      lastLockTime=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].lastLockTime;
      weightTime=db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].weightTime;
    }

    function queryUserStaking(address userAddr,uint lockType) external view returns(uint stakingAmount,uint tatalBonus,uint lastBonusTime){
      if(lockType==0){
         //PoolA
         stakingAmount=db.stakingTable.poolA[db.config.dotcContract].accountStakings[userAddr].balance;
         tatalBonus=db.stakingTable.poolA[db.config.dotcContract].accountStakings[userAddr].totalBonused;
         lastBonusTime=db.stakingTable.poolA[db.config.dotcContract].accountStakings[userAddr].lastBonusTime;
       }else{
         //PoolB
         stakingAmount=db.stakingTable.poolB[db.config.dotcContract].accountStakings[userAddr].balance;
         tatalBonus=db.stakingTable.poolB[db.config.dotcContract].accountStakings[userAddr].totalBonused;
         lastBonusTime=db.stakingTable.poolB[db.config.dotcContract].accountStakings[userAddr].lastBonusTime;
       }
    }
    function queryPoolInfo(uint lockType) external view returns(uint totalSupply,uint totalAccount,uint totalUSDTBonus,uint totalBonused){
      if(lockType==0){
        //PoolA
        totalSupply=db.stakingTable.poolA[db.config.dotcContract].totalSupply;
        totalAccount=db.stakingTable.poolA[db.config.dotcContract].totalAccount;
        totalUSDTBonus=db.stakingTable.poolA[db.config.dotcContract].totalUSDTBonus;
        totalBonused=db.stakingTable.poolA[db.config.dotcContract].totalBonused;
      }else{
        //Pool B
        totalSupply=db.stakingTable.poolB[db.config.dotcContract].totalSupply;
        totalAccount=db.stakingTable.poolB[db.config.dotcContract].totalAccount;
        totalUSDTBonus=db.stakingTable.poolB[db.config.dotcContract].totalUSDTBonus;
        totalBonused=db.stakingTable.poolB[db.config.dotcContract].totalBonused;
      }
    }
     function getMyBonus(uint lockType) external returns (bool result) {
      require(db.stakingTable.isEnableBonus,'staking bonus is paused now');

      if(lockType==0){
        //PoolA
        //lock time
        require((block.timestamp.sub(db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].weightTime))>=consts.stakingParam.firstBonusTime,'lock time inside 30 days');
        uint lastBonusTime=block.timestamp.sub(db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].lastBonusTime);
        require(lastBonusTime>=consts.stakingParam.bonusWaitTime,'you can not get bonus right now.');
        result=_takeBonus(db.stakingTable.poolA[db.config.dotcContract],db.stakingTable.poolA[db.config.dotcContract].accountStakings[msg.sender].balance);
       }else{
        //PoolB
        //lock time
        require((block.timestamp.sub(db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].weightTime))>=consts.stakingParam.firstBonusTime,'lock time inside 30 days');
        uint lastBonusTime=block.timestamp.sub(db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].lastBonusTime);
        require(lastBonusTime>=consts.stakingParam.bonusWaitTime,'you can not get bonus right now.');
        result=_takeBonus(db.stakingTable.poolB[db.config.dotcContract],db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].balance);
       }
       result=true;

    }
    function getWeightTime() external view returns(uint){
      return db.stakingTable.poolB[db.config.dotcContract].accountStakings[msg.sender].weightTime;
    }
    function WeightTimeTest(uint oldBalance,uint oldWeightTime,uint newAmount) internal view returns(uint){
      return _RecalculateWeightTime(oldBalance,oldWeightTime,newAmount);
    }
    function _RecalculateWeightTime(uint oldBalance,uint oldWeightTime,uint newAmount) internal view returns(uint newWeightTime){
       if(oldBalance==0){
         newWeightTime=block.timestamp;
       }else{
         uint oldLockTime=block.timestamp.sub(oldWeightTime)/86400;
         if(oldLockTime<1) oldLockTime=1;
         uint newBalance=oldBalance.add(newAmount);
         require(newBalance>0,'new Balance is 0');
         uint nTotal=oldBalance.mul(oldLockTime).add(newAmount);
         uint nNewLockTime=nTotal.div(newBalance);
         newWeightTime=block.timestamp.sub(nNewLockTime);
       }
    }
    function _takeBonus(StakingPool storage pool,uint amount) internal returns(bool result){
       uint availBonus=_calculateAvailBonus(pool,amount);
       require(availBonus<pool.totalUSDTBonus,'bonus overflow');
       //give bonus
       db.userTable.userAssets[msg.sender][db.config.usdtContract].available=db.userTable.userAssets[msg.sender][db.config.usdtContract].available.add(availBonus);
       pool.totalUSDTBonus= pool.totalUSDTBonus.sub(availBonus);
       //update bonus time
       pool.accountStakings[msg.sender].lastBonusTime=block.timestamp;
       pool.accountStakings[msg.sender].totalBonused=pool.accountStakings[msg.sender].totalBonused.add(availBonus);
       pool.totalBonused=pool.totalBonused.add(availBonus);

       result=true;
       emit _stakingBonused(msg.sender,db.config.dotcContract,availBonus);
    }
    function _calculateAvailBonus(StakingPool storage pool,uint amount) internal view returns(uint avail){
       if(amount<=0) return 0;
       //require(amount>0,"amount must be greater than 0");
       if(pool.totalSupply==0){
         return 0;
       }
       {
         uint balance=pool.accountStakings[msg.sender].balance;
         require(balance>=amount,"insufficient unlock balance");

         uint nLockDays=block.timestamp.sub(pool.accountStakings[msg.sender].weightTime)/86400;
         if(nLockDays<1) nLockDays=1;
         uint stakingDays=block.timestamp.sub(db.stakingTable.startTime)/86400;
         if(stakingDays<1) stakingDays=1;
         require(nLockDays<=stakingDays,'lockDays must be error');
         avail=balance.mul(nLockDays).mul(pool.totalUSDTBonus).div(stakingDays).div(pool.totalSupply);
       }


    }
}
