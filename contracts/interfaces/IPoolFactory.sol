pragma solidity 0.7.6;

interface IPoolFactory {
    function createPool(address oracleAddress_, address poolToken) external;

    function pools(address poolToken, address oracleAddress) external view returns (address pool);
    function deletePool(address oracleAddress_, address poolToken)external;
    struct CreatePool{
        address poolToken;
        address oracleAddress;
        address pool;
        address debt;
        string tradePair;
    }

    struct DeletePool{
        address poolToken;
        address oracleAddress;
    }


}
