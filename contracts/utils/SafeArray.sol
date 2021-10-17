// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;

library SafeArray {
    
    function RemoveItem(uint[] storage data,uint userAddr) internal {
        
        if(data.length<1) return ;
        (bool isFind,uint index)=Contains(data,userAddr);
        if(isFind){
            if(index<data.length-1){
            for(uint y=index;y<data.length-1;y++){
                data[y]=data[y+1];
            }
            }
            data.pop();
        }
    }

    function Contains(uint[] memory data,uint num) internal pure returns(bool isFind,uint index){
        
        for(uint i=0;i<data.length;i++){
            if(data[i]==num){
                isFind=true;
                index=i;
                break;
            }
        }
    }
    
}