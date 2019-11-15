pragma solidity ^0.4.24;

contract SimpleStorage {
    uint storedData;

    function set(uint _x) public {
        storedData = _x;
    }

    function get() public view returns (uint) {
        return storedData;
    }
}