// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import "../facetBase/DOTCFacetBase.sol";

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibERC20.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IFeeFacet.sol";

import '../utils/SafeMath.sol';


contract DOTCFeeFacet is DOTCFacetBase,IFeeFacet {
    using SafeMath for uint; 

    function getMakerFee() external view  override returns (uint) {
       return db.config.makerFee;
    }

    function setMakerFee(uint _fee) external override returns(bool result){
       LibDiamond.enforceIsContractManager();
       require(_fee>=0,'fee must be greater than 0');
       require(_fee<10000,'fee must be less than 10000');
       db.config.makerFee=_fee;
       result=true;
       emit feeChanged(0,_fee);
    }

    function getTakerFee() external view override returns(uint){
        return db.config.takerFee;
    }

    function setTakerFee(uint _fee) external override returns(bool result){
       LibDiamond.enforceIsContractManager();
       require(_fee>=0,'fee must be greater than 0');
       require(_fee<10000,'fee must be less than 10000');
       db.config.takerFee=_fee;
       result=true;
       emit feeChanged(1,_fee);
    }
}


