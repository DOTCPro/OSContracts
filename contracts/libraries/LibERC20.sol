// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.0;

import "../interfaces/IERC20.sol";

library LibERC20 {

   function approveQuery(address _token,address _spender) internal view returns(uint256 _amount){
       _amount=IERC20(_token).allowance(msg.sender,_spender);
   }

   function queryDecimals(address _token) internal view returns(uint256 decimals){
       decimals=IERC20(_token).decimals();
   }

    function transferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _value
    ) internal {
        uint256 size;
        assembly {
            size := extcodesize(_token)
        }
        require(size > 0, "LibERC20: Address has no code");
        (bool success, bytes memory result) = _token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _value));
        handleReturn(success, result);
    }

    function transfer(
        address _token,
        address _to,
        uint256 _value
    ) internal {
        uint256 size;
        assembly {
            size := extcodesize(_token)
        }
        require(size > 0, "LibERC20: Address has no code");
        (bool success, bytes memory result) = _token.call(abi.encodeWithSelector(IERC20.transfer.selector, _to, _value));
        handleReturn(success, result);
    }

    function handleReturn(bool _success, bytes memory _result) internal pure {
        if (_success) {
            if (_result.length > 0) {
                require(abi.decode(_result, (bool)), "LibERC20: contract call returned false");
            }
        } else {
            if (_result.length > 0) {
                // bubble up any reason for revert
                revert(string(_result));
            } else {
                revert("LibERC20: contract call reverted");
            }
        }
    }
}
