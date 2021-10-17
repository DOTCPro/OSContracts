// SPDX-License-Identifier: GPL-3.0 
pragma solidity >=0.7.0;


library SignHelper{
    //验证签名入口函数
  function checkSign(string memory originData,string memory signedStr,address signer ) internal pure returns (bool isValid){
      bytes memory signedString =bytes(signedStr);
      isValid= (signer==ecrecoverDecode(originData,bytesToBytes32(slice(signedString,0,32)),bytesToBytes32(slice(signedString,32,32)),slice(signedString,64,1)[0]));
  }
  //切片函数
  function slice(bytes memory data,uint start,uint len) internal pure returns(bytes memory){
      bytes memory b=new bytes(len);
      for(uint i=0;i<len;i++){
          b[i]=data[i+start];
      }
      return b;
  }
  //使用ecrecover恢复出公钥，后对比
  function ecrecoverDecode(string memory originData,bytes32 r,bytes32 s, byte v1) internal pure returns(address addr){
      addr=ecrecover(bytesToBytes32(bytes(originData)), uint8(v1)+27, r, s);
  }
  //bytes转换为bytes32
  function bytesToBytes32(bytes memory source) internal pure returns(bytes32 result){
      assembly{
          result :=mload(add(source,32))
      }
  }
}