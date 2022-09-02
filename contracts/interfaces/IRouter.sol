pragma solidity 0.7.6;

interface IRouter {
    function createPool(
        address oracleAddress,
        address poolToken
    ) external;


    function getLsBalance(
        address oracleAddress,
        address poolToken,
        address user
    ) external view returns (uint256);

    function getLsPrice(
        address oracleAddress,
        address poolToken
    ) external view returns (uint256);

    function addLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 amount
    ) external payable;

    function removeLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 lsAmount,
        uint256 bondsAmount,
        address receipt
    ) external;

    function openPosition(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position
    ) external payable;

    function addMargin(uint32 tokenId, uint256 margin) external payable;

    function closePosition(uint32 tokenId, address receipt) external;

    function liquidate(uint32 tokenId, address receipt) external;

    function liquidateByPool(address poolAddress, uint32 positionId, address receipt) external;

    function withdrawERC20(address poolToken) external;

    function withdrawETH() external;

    function repayLoan(
        address oracleAddress,
        address poolToken,
        uint256 amount,
        address receipt
    ) external payable;

    event TokenCreate(uint32 tokenId, address pool, address sender, uint32 positionId);
}
