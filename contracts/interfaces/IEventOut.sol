pragma solidity 0.7.6;

interface IEventOut {
    event OutEvent(
        address indexed sender,
        uint32 itype,
        bytes bvalue
    );

    function eventOut(uint32 _type,bytes memory _value) external ;
}