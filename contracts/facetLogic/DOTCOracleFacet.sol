// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import '../oracle/libraries/IUniswapV2Factory.sol';
import '../oracle/libraries/IUniswapV2Pair.sol';
import '../oracle/libraries/FixedPoint.sol';
import '../oracle/libraries/UniswapV2OracleLibrary.sol';
import '../oracle/libraries/UniswapV2Library.sol';

import '../oracle/IPairOracleBot.sol';
import '../oracle/PairOracleBot.sol';

import "../facetBase/DOTCFacetBase.sol";
import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";

import '../utils/SafeMath.sol';

contract DOTCOracleFacet is DOTCFacetBase {
    using SafeMath for uint; 
    using FixedPoint for *;
    uint public constant PERIOD = 4 hours;
    //IUniswapV2Pair immutable pair;
    IPairOracleBot pairBotDOTC_ETH;
    IPairOracleBot pairBotETH_USDT;

    address public  dotcAddr;
    address public  wethAddr;
    address public usdtAddr;
    address public uniFactoryAddr;

    bool public isUniReady;

    uint lastUpdateTime=0;
    uint priceDOTCETH=0;
    uint priceETHUSDT=0;
    
    //当前价格
    uint public currentPrice=0;

    bool public isTwoPair=false;

    event _DOTCPriceUpdated(uint price,uint price0,uint price1); 
    event _UniAddressUpdated(address _uniFactory, address _dotcAddr, address _wethAddr,address _usdtAddr,bool _isTwoPair);
    //admin set
    function updateUniAddress(address _uniFactory, address _dotcAddr, address _wethAddr,address _usdtAddr,bool _isTwoPair) external {
         LibDiamond.enforceIsContractOwner();
         require(_dotcAddr==db.config.dotcContract,'token must be DOTC');
         pairBotDOTC_ETH=IPairOracleBot(createPairOracle(_uniFactory,_dotcAddr,_wethAddr));
         isTwoPair=_isTwoPair;
         if(isTwoPair){
             pairBotETH_USDT=IPairOracleBot(createPairOracle(_uniFactory,_wethAddr,_usdtAddr));
         }
         uniFactoryAddr=_uniFactory;
         dotcAddr=_dotcAddr;
         wethAddr=_wethAddr;
         usdtAddr=_usdtAddr;

         isUniReady=true;
         emit _UniAddressUpdated(_uniFactory,_dotcAddr,_wethAddr,_usdtAddr,_isTwoPair);
    }
    function getOracleInfo() external view returns(address,address,address,address){
        return (uniFactoryAddr,dotcAddr,wethAddr,usdtAddr);
    }
    //admin set
    function forceUpdate() external {
       LibDiamond.enforceIsContractManager();
       _update();
    }

    function _update() internal {
        if(consts.priceMode==1){
            return;
        }
        require(isUniReady,'Uniswap is not ready');
        pairBotDOTC_ETH._update();
        priceDOTCETH=pairBotDOTC_ETH._getCurrentPrice(dotcAddr);
        if(isTwoPair){
           pairBotETH_USDT._update();  
           priceETHUSDT=pairBotETH_USDT._getCurrentPrice(wethAddr);
           //update storage
           currentPrice=priceDOTCETH.mul(priceETHUSDT);
        }
        else{
              //update storage
           currentPrice=priceDOTCETH;
        }
        //update storage
        db.daoData.oracleInfo.currentPrice=currentPrice * 10 ** 6;
        db.daoData.oracleInfo.isInited=true;
        db.daoData.oracleInfo.lastUpdateTime=block.timestamp;
        lastUpdateTime=block.timestamp;

        emit _DOTCPriceUpdated(_getCurrentPrice(),priceDOTCETH,priceETHUSDT);
    }

    function getTwoPriceValue() external view returns(uint,uint){ 
       return (priceDOTCETH,priceETHUSDT);
    }
    function getPriceMode() external view returns(uint priceMode){ 
       return consts.priceMode;
    }
    function checkUpdatePrice() external returns(bool){
      uint timeElapsed = block.timestamp - lastUpdateTime; // overflow is desired
      if(timeElapsed >= PERIOD){
        //update info 
        _update();
        return true;
      }
      return false;
    }
    function getDotcPrice() external view returns (uint){
        return _getCurrentPrice();
    }
    function createPairOracle(address uniAddr,address tokenA, address tokenB) internal returns (address pair) {
        bytes memory bytecode = type(PairOracleBot).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(uniAddr,tokenA, tokenB));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPairOracleBot(pair)._initPairOracle(uniAddr,tokenA, tokenB);
    }

    function _getCurrentPrice() internal view returns(uint price){
        //手动模式，直接返回设置的价格
        price=db.daoData.oracleInfo.currentPrice;
        uint nMin=nDOTCDecimals/1000;
        if(price<nMin){
            price=nMin;
        }
        return price;
    }  

}