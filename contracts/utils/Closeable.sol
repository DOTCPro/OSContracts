// SPDX-License-Identifier: GPL-3.0 
pragma solidity 0.7.0;

import './Ownable.sol';

contract Closeable is Ownable {
    event _ClosePublic();
    event _OpenPublic();

    bool public isClosePublic = false;


    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenOpenPublic() {
        require(!isClosePublic);
        _;
    }

        /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenClosePublic() {
        require(isClosePublic);
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function closePublic() onlyOwner whenOpenPublic public {
        isClosePublic = true;
        emit _ClosePublic();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner whenClosePublic public {
        isClosePublic = false;
        emit _OpenPublic();
    }
}