// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
/******************************************************************************/

interface IFeeFacet {
    /******** DOTCFee START***/
    event feeChanged(uint feetype,uint fee);

    function getMakerFee() external view returns (uint);

    function setMakerFee(uint _fee) external returns(bool result);

    function getTakerFee() external view returns(uint);

    function setTakerFee(uint _fee) external returns(bool result);
}
