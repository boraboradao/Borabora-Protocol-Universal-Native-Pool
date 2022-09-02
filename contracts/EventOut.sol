pragma solidity 0.7.6;
import "./interfaces/IEventOut.sol";

contract EventOut is IEventOut  {
    function eventOut(uint32 _type,bytes memory _value) external override {
        emit OutEvent(msg.sender,_type,_value);
    }
}