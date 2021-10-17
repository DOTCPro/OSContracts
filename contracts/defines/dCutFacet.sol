// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

import "../interfaces/IDiamondCut.sol";

struct FacetInfo{
    uint256 _selectorCount;
    bytes32 _selectorSlot;
    address _newFacetAddress;
    IDiamondCut.FacetCutAction _action;
    bytes4[] _selectors;
}