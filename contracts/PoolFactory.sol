pragma solidity 0.7.6;
pragma abicoder v2;

import "./libraries/StrConcat.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IDeployer01.sol";
import "./interfaces/IPool.sol";
import "./interfaces/ISettingManager.sol";
import "./interfaces/IEventOut.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PoolFactory is IPoolFactory {
    mapping(address => mapping(address =>address)) public override pools;

    address private _deployer01;
    address public _setting;

    constructor(
        address deployer01,
        address setting) {
        _deployer01 = deployer01;
        _setting = setting;
    }

    function deletePool(address oracleAddress_, address poolToken)external override {
        require(pools[poolToken][oracleAddress_] != address(0), "pool does not exists");

        address poolAddress = pools[poolToken][oracleAddress_];
        require(IPool(poolAddress)._liquidityPool() == 0,"pool liquidity should be empty");//这个是否必要？先留着把
        require(!ISettingManager(_setting).isPoolActive(poolAddress),"can not delete an active pool");
        delete pools[poolToken][oracleAddress_];
        // DeletePool memory _data = DeletePool(oracleAddress_,poolToken);
        bytes memory eventData = abi.encode(oracleAddress_,poolToken);
        IEventOut(ISettingManager(_setting).eventOut()).eventOut(2,eventData);
    }


    function createPool(address oracleAddress_, address poolToken) external override {
        require(oracleAddress_ != address(0), "trade pair can not be zero");
        require(pools[poolToken][oracleAddress_] == address(0), "pool already exists");

        string memory tradePair = StrConcat.strConcat("LP",ERC20(poolToken).symbol());
        (address pool, address debt) = IDeployer01(_deployer01).deploy(poolToken, oracleAddress_, _setting, tradePair);
        pools[poolToken][oracleAddress_] = pool;

        bytes memory eventData = abi.encode(poolToken, oracleAddress_, pool, debt, tradePair);
        IEventOut(ISettingManager(_setting).eventOut()).eventOut(1,eventData);

    }


}
