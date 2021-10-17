// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

import './libraries/IUniswapV2Factory.sol';
import './libraries/IUniswapV2Pair.sol';
import './libraries/FixedPoint.sol';
import './libraries/UniswapV2OracleLibrary.sol';
import './libraries/UniswapV2Library.sol';

import './IPairOracleBot.sol';
import '../utils/SafeMath.sol';

contract PairOracleBot is IPairOracleBot {

    using SafeMath for uint; 
    using FixedPoint for *;   
    
    IUniswapV2Pair  pair;
    address public  token0;
    address public  token1;
    address public uniFactoryAddr;

    uint    public price0CumulativeLast;
    uint    public price1CumulativeLast;
    uint32  public blockTimestampLast;
   
    FixedPoint.uq112x112 price0Average;
    FixedPoint.uq112x112 price1Average;

    bool public isUniReady;


    function _initPairOracle(address _uniFactory, address _token0, address _token1) override external {
      _initPair(_uniFactory,_token0,_token1);
      isUniReady=true;
    }

     function _initPair(address _uniFactory, address _token0, address _token1) internal{
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(_uniFactory, _token0, _token1));
        require(_pair.token0()!=address(0),'pair not exist');
        pair = _pair;
        token0 = _pair.token0();
        token1 = _pair.token1();
        uniFactoryAddr=_uniFactory;
        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, 'DOTCOracleFacet: NO_RESERVES'); // ensure that there's liquidity in the pair
    }

    function _update() override external {
        require(isUniReady,'Uniswap is not ready');
        // ensure that at least one full period has passed since the last update
        //require(timeElapsed >= PERIOD, 'ExampleOracleSimple: PERIOD_NOT_ELAPSED');

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
         
        require(timeElapsed>0,'timeElapsed error');
        // ensure that at least one full period has passed since the last update
        //require(blockTimestampLast || timeElapsed >= PERIOD, 'DOTCOracleFacet: PERIOD_NOT_ELAPSED');
        price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
        price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));
       
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
        
    }

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint amountIn) internal view returns (uint amountOut) {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, 'DOTCOracleFacet: INVALID_TOKEN');
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    function _getCurrentPrice(address targetToken) override external view returns(uint price){
        if(token0==targetToken){
           price=price0Average.decode();
        }else{
           price=price1Average.decode();
        }
        return price;
    }  
}