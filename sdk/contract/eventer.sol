pragma solidity ^0.4.24;

contract simple_storage_1 {
    uint storedData;

    event event0(address addr, string message);
    event event1(uint x);

    function set(uint _x) public{
        storedData = _x;
        emit event0(msg.sender, "setting storage~");
        emit event1(_x);
    }

    function get() public view returns (uint) {
        emit event0(msg.sender, "getting storage!");
        emit event1(storedData);
        return storedData;
    }
}