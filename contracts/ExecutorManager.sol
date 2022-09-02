pragma solidity 0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IExecutorManager.sol";
import "./interfaces/IEventOut.sol";


contract ExecutorManager is Multicall, Ownable ,IExecutorManager{
    event AddLegalExecutor(
        address indexed user
    );

    event RemoveLegalExecutor(
        address indexed user
    );

    address public _eventOut;

    constructor() {
    }

    mapping(address => bool) public _legalExecutor;

    function setEventOut(address eventAddress)  public onlyOwner  {
        _eventOut = eventAddress;
    }

    function addLegalExecutor(address user) external override onlyOwner {
        _legalExecutor[user] = true;
        bytes memory eventData = abi.encode(user);
        IEventOut(_eventOut).eventOut(1,eventData);
        // emit AddLegalExecutor(user);
    }

    function removeLegalExecutor(address user) external override onlyOwner {
        _legalExecutor[user] = false;        
        bytes memory eventData = abi.encode(user);
        IEventOut(_eventOut).eventOut(2,eventData);
        // emit RemoveLegalExecutor(user);
    }

    function IsLegalExecutor(address user) external override view returns(bool) {
        return _legalExecutor[user];
    }
}