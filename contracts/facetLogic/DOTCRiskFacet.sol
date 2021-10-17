// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../facetBase/DOTCFacetBase.sol";

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";

import '../utils/SafeMath.sol';

contract DOTCRiskFacet is DOTCFacetBase  {
     using SafeMath for uint; 
     event _RiskTokenAdded(address userAddr,address token,uint amount); 
     event _RiskTokenRemoved(address userAddr,address token,uint amount); 
     
     function AddTokenToRiskPool(address token,uint amount) external returns(bool result){
       require(token!=address(0),'token invalid');
       require(amount>0,'amount must be greater than 0');
       uint balance= IERC20(token).balanceOf(msg.sender);
       require(balance>=amount,'insufficient token balance');
       LibDiamond.enforceIsContractManager();
       //开始转账

       LibERC20.transferFrom(token, msg.sender, address(this), amount);
       db.daoData.riskPool.poolTokens[token].currentSupply=db.daoData.riskPool.poolTokens[token].currentSupply.add(amount);
       db.daoData.riskPool.poolTokens[token].initSupply=db.daoData.riskPool.poolTokens[token].initSupply.add(amount);        
       emit _RiskTokenAdded(msg.sender,token,amount);
       result=true;
     }

     function RemoveTokenFromRiskPool(address token,uint amount) external returns(bool result){
        require(token!=address(0),'token invalid');
        require(amount>0,'amount must be greater than 0');
        require(db.daoData.riskPool.poolTokens[token].currentSupply>=amount,'insufficient pool balance');
        LibDiamond.enforceIsContractOwner();
        LibERC20.transfer(token, msg.sender, amount);
        db.daoData.riskPool.poolTokens[token].currentSupply=db.daoData.riskPool.poolTokens[token].currentSupply.sub(amount);
        emit _RiskTokenRemoved(msg.sender,token,amount);
        result=true;
     }

     function queryRiskPoolInfo(address tokenAddr) external view returns(PoolInfo memory poolInfo){
         poolInfo=db.daoData.riskPool.poolTokens[tokenAddr];
     }

}
