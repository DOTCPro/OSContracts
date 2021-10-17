// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.0;

// helper generate serveral random numbers.
library RandomHelper {

    function rand(uint _length,uint nonce) internal view  returns(uint) {
        require(_length!=0,"max num is zero");
        uint random = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp,msg.sender,nonce)));
        return  random%_length;
    }     
    
}
