// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;
import "../facetBase/DOTCFacetBase.sol";
import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";

import '../utils/SafeMath.sol';

contract DOTCMiningFacet is DOTCFacetBase {
     using SafeMath for uint; 
     event _MineTokenAdded(address userAddr,address token,uint amount); 
     event _MineTokenRemoved(address userAddr,address token,uint amount); 
     event _MineParamReseted(address userAddr,uint nBackRate); 
     
     function AddTokenToPool(address token,uint amount) external returns(bool result){
       require(token!=address(0),'token invalid');
       require(amount>0,'amount must be greater than 0');
       require(token==db.config.dotcContract,'only dotc is supported');
       uint balance= IERC20(token).balanceOf(msg.sender);
       require(balance>=amount,'insufficient token balance');
       LibDiamond.enforceIsContractManager();
       //开始转账

       LibERC20.transferFrom(token, msg.sender, address(this), amount);
       if(db.daoData.miningPool.poolTokens[token].initSupply<=0){
          _resetPoolParams(700);
       }
       db.daoData.miningPool.poolTokens[token].currentSupply=db.daoData.miningPool.poolTokens[token].currentSupply.add(amount);
       db.daoData.miningPool.poolTokens[token].initSupply=db.daoData.miningPool.poolTokens[token].initSupply.add(amount);
      
       emit _MineTokenAdded(msg.sender,token,amount);

       result=true;
     }

     function RemoveTokenFromPool(address token,uint amount) external returns(bool result){
        require(token!=address(0),'token invalid');
        require(amount>0,'amount must be greater than 0');
        require(db.daoData.miningPool.poolTokens[token].currentSupply>=amount,'insufficient pool balance');
        LibDiamond.enforceIsContractOwner();
        LibERC20.transfer(token, msg.sender, amount);
        db.daoData.miningPool.poolTokens[token].currentSupply=db.daoData.miningPool.poolTokens[token].currentSupply.sub(amount);
        emit _MineTokenRemoved(msg.sender,token,amount);
        result=true;
     }

     function ResetPoolParams(uint nBackRate) external returns(bool result){
        LibDiamond.enforceIsContractManager();
        _resetPoolParams(nBackRate);
        result=true;
        emit _MineParamReseted(msg.sender,nBackRate);
     }

     function _resetPoolParams(uint nBackRate) internal {
        require(nBackRate<=1000 && nBackRate>=0,'invalid back rate');
        db.daoData.miningPool.poolTokens[db.config.dotcContract].initBackRate=nBackRate;
        db.daoData.miningPool.poolTokens[db.config.dotcContract].periodMined=0;
        db.daoData.miningPool.poolTokens[db.config.dotcContract].periodCount=0;
     }

     function queryMingPoolInfo(address tokenAddr) external view returns(MineInfo memory mineInfo){
         mineInfo=db.daoData.miningPool.poolTokens[tokenAddr];
     }


}
