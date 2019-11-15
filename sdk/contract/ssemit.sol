pragma solidity ^0.4.24;

contract SimpleStorage {
    uint storedData;
    
    event setTo(uint x);
    
    function set(uint _x) public {
        storedData = _x;
        emit setTo(_x);
    }

    function get() public view returns (uint) {
        return storedData;
    }
}