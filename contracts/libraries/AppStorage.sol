// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

import '../defines/dUser.sol';
import '../defines/dOrder.sol';
import '../defines/dRisk.sol';
import '../defines/dMiningPool.sol';
import '../defines/dStaking.sol';
import '../defines/dArbit.sol';
import '../defines/dCommon.sol';

struct DAOData{
    /*****Risk Pool */
    RiskPool riskPool;
    /**** Mining Pool */
    MiningPool miningPool;
    /******Oracle Start ******/
    OracleInfo oracleInfo;
}
library LibAppStorage {
     bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamondApp.standard.dotc.storage");
    //Diamond Storage data
    struct AppStorage {
        Config config;
        /****** AdOrder ****/
        OrderTable orderTable;
        /****** AdUser ****/
        UserTable userTable;
        /****** DOTCArbit ****/
        ArbitTable arbitTable;
        /****** DOTCStaking ****/
        StakingTable stakingTable;
        /*******DAO data */
        DAOData daoData;
    }
    
    function appStorage() internal pure returns (AppStorage storage es) {
     bytes32 position = DIAMOND_STORAGE_POSITION;
     assembly {
       es.slot := position
    }
  }

}
