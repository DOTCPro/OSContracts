// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;


interface IPairOracleBot {

   function _initPairOracle(address _uniFactory, address _token0, address _token1) external;
   
   function _update() external;
   
   function _getCurrentPrice(address targetToken) external view returns(uint price);
   
}