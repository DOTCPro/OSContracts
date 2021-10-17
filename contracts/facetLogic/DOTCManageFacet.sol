// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../facetBase/DOTCFacetBase.sol";
import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IDOTCManageFacet.sol";

import '../utils/SafeMath.sol';

contract DOTCManageFacet is DOTCFacetBase,IDOTCManageFacet {
   using SafeMath for uint; 

   function setContractManager(address _newManager) external returns(bool result) {
      LibDiamond.enforceIsContractOwner();
      LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
      address previousManager = ds.contractManager;
      ds.contractManager = _newManager;
      result=true;
      emit ManagerTransferred(previousManager, _newManager);
   }
   function getContractManager() external view returns (address contractManager_) {
      contractManager_ = LibDiamond.diamondStorage().contractManager;
   }
   function updateUnitAddress(address _dotcContract,address _wethContract) external {
      LibDiamond.enforceIsContractOwner();
      require(_dotcContract != address(0), "DOTCFactoryDiamond: dotcContract can't be address(0)");
      require(_wethContract != address(0), "DOTCFactoryDiamond: wethContract can't be address(0)");
      db.config.dotcContract = _dotcContract;
      db.config.wethContract = _wethContract;
      emit _UnitUpdated(_dotcContract,_wethContract);
   }
   function queryUserBalance(address userAddr,address token) external view returns (uint avail,uint locked,uint canUnlocked,uint nonUnlocked) {
      LibDiamond.enforceIsContractManager();
      avail=db.userTable.userAssets[userAddr][token].available;
      locked=db.userTable.userAssets[userAddr][token].locked;
      (canUnlocked,nonUnlocked)=_queryUnlockedAmount(userAddr,token);
   }  
   function setPriceMode(uint mode) external{
      LibDiamond.enforceIsContractManager();
      require(mode>=0 && mode<2,'invalid mode');
      consts.priceMode=mode;
      emit _PriceModeChanged(msg.sender,mode);
   } 
   function setManualDOTCPrice(uint price) external{
      LibDiamond.enforceIsContractManager();
      require(consts.priceMode==1,'DOTC Price mode is auto');
      db.daoData.oracleInfo.currentPrice=price;
      db.daoData.oracleInfo.isInited=true;
      db.daoData.oracleInfo.lastUpdateTime=block.timestamp;
      emit _PriceManualChanged(msg.sender,price);
   } 
   function queryVIPConditionAmount() external view returns (uint) {
      return consts.vipDOTC;
   }
   function setVIPConditionAmount(uint amount) external {
      LibDiamond.enforceIsContractManager();
      require(amount>=nDOTCDecimals,"amount is too little");
      consts.vipDOTC=amount;
      emit _VIPConditionUpdated(msg.sender,amount);
   }
   function queryArbitConditionAmount() external view returns (uint) {
      return consts.arbiterDOTC;
   }
   function setArbitConditionAmount(uint amount) external {
      LibDiamond.enforceIsContractManager();
      require(amount>=nDOTCDecimals,"amount is too little");
      consts.arbiterDOTC=amount;
      emit _ArbitConditionUpdated(msg.sender,amount);
   }
   //staking management
   function setStakingStartTime(uint startTime) external returns(bool result){
      LibDiamond.enforceIsContractManager();
      require(startTime==0 || startTime>=block.timestamp,'invalid staking time');
      if(startTime==0){
         startTime=block.timestamp;
      }
      db.stakingTable.startTime=startTime;
      result=true;
      emit _StakingTimeUpdated(msg.sender,db.stakingTable.startTime);
   }
   function getStakingStartTime() external view returns(uint){
      return db.stakingTable.startTime;
   }
   function setStakingParam(bool enableLock,bool enableUnLock,bool enableBonus) external returns(bool result){
      LibDiamond.enforceIsContractManager();
      db.stakingTable.isEnableLock=enableLock;
      db.stakingTable.isEnableUnLock=enableUnLock;
      db.stakingTable.isEnableBonus=enableBonus;
      result=true;
      emit _StakingParamUpdated(msg.sender,enableLock,enableUnLock,enableBonus);
   }
   function getStakingParam() external view returns(bool enableLock,bool enableUnLock,bool enableBonus){
      enableLock= db.stakingTable.isEnableLock;
      enableUnLock=db.stakingTable.isEnableUnLock;
      enableBonus=db.stakingTable.isEnableBonus;
   }
   function getStakingMin() external view returns(uint poolAMin,uint poolBMin){
      poolAMin= consts.stakingParam.poolAMin;
      poolBMin=consts.stakingParam.bonusUnlockTime;
   }
   function setStakingMin(uint poolAMin,uint poolBMin) external returns(bool result){
      LibDiamond.enforceIsContractManager();
      consts.stakingParam.poolAMin=poolAMin;
      consts.stakingParam.poolBMin=poolBMin;
      result=true;
   }
   function getArbitParam() external view returns(uint nOrderArbitCost,uint nCardArbitCost){
      nOrderArbitCost=consts.arbitParam.nOrderArbitCost;
      nCardArbitCost=consts.arbitParam.nCardArbitCost;
   }
   function setArbitParam(uint nOrderArbitCost,uint nCardArbitCost) external returns(bool result){
      LibDiamond.enforceIsContractManager();
      consts.arbitParam.nOrderArbitCost=nOrderArbitCost;
      consts.arbitParam.nCardArbitCost=nCardArbitCost;
      result=true;
      emit _ArbitParamUpdated(msg.sender,nOrderArbitCost,nCardArbitCost);
   }
   function getUnlockParam() external view returns(uint unLockWaitTime,uint bonusUnlockTime){
      unLockWaitTime= consts.stakingParam.unLockWaitTime;
      bonusUnlockTime=consts.stakingParam.bonusUnlockTime;
   }
   function setUnlockParam(uint unLockWaitTime,uint bonusUnlockTime) external returns(bool result){
      LibDiamond.enforceIsContractManager();
      consts.stakingParam.unLockWaitTime=unLockWaitTime;
      consts.stakingParam.bonusUnlockTime=bonusUnlockTime;
      result=true;
      emit _UnlockParamUpdated(msg.sender,unLockWaitTime,bonusUnlockTime);
   }
   function getBonusParam() external view returns(uint firstBonusTime,uint bonusWaitTime){
      firstBonusTime= consts.stakingParam.firstBonusTime;
      bonusWaitTime= consts.stakingParam.bonusWaitTime;
   }
   function setBonusParam(uint firstBonusTime,uint bonusWaitTime) external returns(bool result){
      LibDiamond.enforceIsContractManager();
      consts.stakingParam.firstBonusTime=firstBonusTime;
      consts.stakingParam.bonusWaitTime=bonusWaitTime;
      result=true;
      emit _BonusParamUpdated(msg.sender,firstBonusTime,bonusWaitTime);
   }
   
}