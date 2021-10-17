// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {

    address public owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    

    /**
     * @dev Set contract deployer as owner
     */
     constructor () {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    // modifier to check if caller is owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0),"newOwner is null.");
        owner = newOwner;
        emit OwnerSet(owner, newOwner);
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}