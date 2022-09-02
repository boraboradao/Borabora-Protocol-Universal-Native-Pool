pragma solidity 0.7.6;
pragma abicoder v2;

import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolCallback.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IDebt.sol";
import "./interfaces/IWETH.sol";

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/base/Multicall.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Router is IRouter, IPoolCallback, Multicall,Ownable {
    fallback() external {}
    receive() payable external {}

    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    address public _factory;
    address public _wETH;
    uint32 private _tokenId = 0;
    uint32 public _ownerRate;
    address public _routerOwner;


    struct tokenDate {
        address user;
        address poolAddress;
        uint32 positionId;
    }

    mapping(uint32 => tokenDate) public _tokenData;

    constructor(address factory, address wETH) {
        _factory = factory;
        _wETH = wETH;
        _ownerRate = 5;
        _routerOwner = msg.sender;
    }

    function setOwnerRate(uint32 ownerRate) public onlyOwner {
        _ownerRate = ownerRate;
    }

    function setRouterOwner(address routeOwner) public onlyOwner {
        _routerOwner = routeOwner;
    }

    function poolV2BondsCallback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override {
        address pool = getPool(oraclePool,poolToken);
        require(
             pool == msg.sender,
            "poolV2BondsCallback caller is not the pool contract"
        );

        address debt = IPool(pool).debtToken();

        IERC20(debt).safeTransferFrom(payer, debt, amount);
    }

    function poolV2BondsCallbackFromDebt(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override {
        address pool = getPool(oraclePool,poolToken);
        require(pool != address(0), "non-exist pool");
        address debt = IPool(pool).debtToken();
        require(
            debt == msg.sender,
            "poolV2BondsCallbackFromDebt caller is not the debt contract"
        );

        IERC20(debt).safeTransferFrom(payer, debt, amount);
    }

    function poolV2Callback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override payable {
        IPoolFactory qilin = IPoolFactory(_factory);
        require(
            qilin.pools(poolToken, oraclePool) == msg.sender,
            "poolV2Callback caller is not the pool contract"
        );

        if (poolToken == _wETH && address(this).balance >= amount) {
            IWETH wETH = IWETH(_wETH);
            wETH.deposit{value: amount}();
            wETH.transfer(msg.sender, amount);
        } else {
            IERC20(poolToken).safeTransferFrom(payer, msg.sender, amount);
        }
    }

    function poolV2RemoveCallback(
        uint256 amount,
        address poolToken,
        address oraclePool,
        address payer
    ) external override {
        IPoolFactory qilin = IPoolFactory(_factory);
        require(
            qilin.pools(poolToken, oraclePool) == msg.sender,
            "poolV2Callback caller is not the pool contract"
        );

        IERC20(msg.sender).safeTransferFrom(payer, msg.sender, amount);
    }

    function getPool(
        address oracleAddress,
        address poolToken
    ) public view returns (address) {
        address pool = IPoolFactory(_factory).pools(poolToken, oracleAddress);
        return pool;
    }

    function createPool(
        address oracleAddress,
        address poolToken
    ) external override {
        IPoolFactory(_factory).createPool(oracleAddress, poolToken);
    }

    function getLsBalance(
        address oracleAddress,
        address poolToken,
        address user
    ) external override view returns (uint256) {
        address pool = getPool(oracleAddress, poolToken);
        require(pool != address(0), "non-exist pool");
        return IERC20(pool).balanceOf(user);
    }

    function getLsPrice(
        address oracleAddress,
        address poolToken
    ) external override view returns (uint256) {
        address pool = getPool(oracleAddress, poolToken);
        require(pool != address(0), "non-exist pool");
        return IPool(pool).lsTokenPrice();
    }

    function addLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 amount
    ) external override payable {
        address poolAddress = getPool(oracleAddress, poolToken);
        require(poolAddress != address(0), "non-exist pool");
        IPool pool = IPool(poolAddress);
        pool.addLiquidity(msg.sender, amount);
    }

    function removeLiquidity(
        address oracleAddress,
        address poolToken,
        uint256 lsAmount,
        uint256 bondsAmount,
        address receipt
    ) external override {
        address poolAddress = getPool(oracleAddress, poolToken);
        require(poolAddress != address(0), "non-exist pool");
        IPool pool = IPool(poolAddress);
        pool.removeLiquidity(msg.sender, lsAmount, bondsAmount, receipt);
    }

    function openPosition(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position
    ) external override payable {
        address poolAddress = getPool(oracleAddress, poolToken);
        require(poolAddress != address(0), "non-exist pool");
        IPool pool = IPool(poolAddress);
        _tokenId++;

        if (_ownerRate > 0) {
            uint256 contribute = position.mul(_ownerRate).div(1e4);

            IERC20(poolToken).safeTransferFrom(
                msg.sender,
                _routerOwner,
                contribute
            );
            position = position.sub(contribute);
            
        }
        uint32 positionId = pool.openPosition(
            msg.sender,
            direction,
            leverage,
            position
        );
        tokenDate memory tempTokenDate = tokenDate(
            msg.sender,
            address(pool),
            positionId
        );
        _tokenData[_tokenId] = tempTokenDate;
        emit TokenCreate(_tokenId, address(pool), msg.sender, positionId);
    }

    function addMargin(uint32 tokenId, uint256 margin) external override payable {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(
            tempTokenDate.user == msg.sender,
            "token owner not match msg.sender"
        );
        IPool(tempTokenDate.poolAddress).addMargin(
            msg.sender,
            tempTokenDate.positionId,
            margin
        );
    }

    function closePosition(uint32 tokenId, address receipt) external override {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(
            tempTokenDate.user == msg.sender,
            "token owner not match msg.sender"
        );
        IPool(tempTokenDate.poolAddress).closePosition(
            receipt,
            tempTokenDate.positionId
        );
    }


    function liquidate(uint32 tokenId, address receipt) external override {
        tokenDate memory tempTokenDate = _tokenData[tokenId];
        require(tempTokenDate.user != address(0), "tokenId does not exist");
        IPool(tempTokenDate.poolAddress).liquidate(
            msg.sender,
            tempTokenDate.positionId,
            receipt
        );
    }

    function liquidateByPool(address poolAddress, uint32 positionId, address receipt) external override {
        IPool(poolAddress).liquidate(msg.sender, positionId, receipt);
    }

    function withdrawERC20(address poolToken) external override {
        IERC20 erc20 = IERC20(poolToken);
        uint256 balance = erc20.balanceOf(address(this));
        require(balance > 0, "balance of router must > 0");
        erc20.safeTransfer(msg.sender, balance);
    }

    function withdrawETH() external override {
        uint256 balance = IERC20(_wETH).balanceOf(address(this));
        require(balance > 0, "balance of router must > 0");
        IWETH(_wETH).withdraw(balance);
        (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
        require(success, "ETH transfer failed");
    }

    function repayLoan(
        address oracleAddress,
        address poolToken,
        uint256 amount,
        address receipt
    ) external override payable {
        address pool = getPool(oracleAddress, poolToken);
        require(pool != address(0), "non-exist pool");
        address debtToken = IPool(pool).debtToken();
        IDebt(debtToken).repayLoan(msg.sender, receipt, amount);
    }

}
