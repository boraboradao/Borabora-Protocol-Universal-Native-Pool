pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./libraries/StrConcat.sol";
import "./libraries/Price.sol";
import "./libraries/BasicMaths.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/IPool.sol";
import "./interfaces/ISettingManager.sol";
import "./interfaces/IPoolCallback.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IDeployer02.sol";
import "./interfaces/IDebt.sol";
import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV2V3Interface.sol";
import "./interfaces/IEventOut.sol";


contract Pool is ERC20, IPool {
    using SafeMath for uint256;
    using BasicMaths for uint256;
    using BasicMaths for bool;
    using SafeERC20 for IERC20;

    address public override  _poolToken;
    address public _settings;
    address public override debtToken;

    address public _oraclePool;

    uint256 public override _lastRebaseBlock = 0;
    uint32 public _positionIndex = 0;
    uint256 public override _poolDecimalDiff;
    mapping(uint32 => Position) public override _positions;

    uint256 public _lsAvgPrice = 1e18;
    uint256 public override _liquidityPool = 0;
    uint256 public override _totalSizeLong = 0;
    uint256 public override _totalSizeShort = 0;
    uint256 public _rebaseAccumulatedLong = 0;
    uint256 public _rebaseAccumulatedShort = 0;

    uint256 private constant StandardDecimal = 18;
    bool public unlocked = true;

    modifier lock() {
        require(unlocked, 'LOK');
        unlocked = false;
        _;
        unlocked = true;
    }

    constructor(
        address poolToken_,
        address oracleAddress_,
        address setting,
        string memory symbol
    ) ERC20(symbol, symbol) {
        uint8 decimals = ERC20(poolToken_).decimals();

        _setupDecimals(decimals);
        _poolToken = poolToken_;
        _settings = setting;
        _poolDecimalDiff = StandardDecimal > ERC20(poolToken_).decimals()
            ? StandardDecimal - ERC20(poolToken_).decimals()
            : 0;
        _oraclePool = oracleAddress_;
        getPrice();
        debtToken = IDeployer02(ISettingManager(setting).getDeployDebtAddress()).deploy(address(this), poolToken_, setting, symbol);
        unlocked = true;
    }

    function getPrice() public override view returns(uint256) {
        uint price = uint(AggregatorV2V3Interface(_oraclePool).latestAnswer());
        uint decimals = StandardDecimal.sub(uint(AggregatorV2V3Interface(_oraclePool).decimals()));

        return price.mul(10 ** decimals);
    }

    function lsTokenPrice() external view override returns (uint256) {
        return
            Price.lsTokenPrice(
                IERC20(address(this)).totalSupply(),
                _liquidityPool
            );
    }

    function poolCallback(address user, uint256 amount) internal lock {
        uint256 balanceBefore = IERC20(_poolToken).balanceOf(address(this));
        IPoolCallback(msg.sender).poolV2Callback(
            amount,
            _poolToken,
            address(_oraclePool),
            user
        );
        require(
            IERC20(_poolToken).balanceOf(address(this)) >=
                balanceBefore.add(amount),
            "poolToken is not enough"
        );
    }

    function _mintLsByPoolToken(uint256 amount) internal {
        uint256 lsTokenAmount = Price.lsTokenByPoolToken(
            IERC20(address(this)).totalSupply(),
            _liquidityPool,
            amount
        );

        _mint(ISettingManager(_settings).getOfficial(), lsTokenAmount);
        bytes memory eventData = abi.encode(address(0),ISettingManager(_settings).getOfficial(), amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(10,eventData);
    }

    function addLiquidity(address user, uint256 amount) external override {
        require(ISettingManager(_settings).isPoolActive(address(this)),"pool is suspended");
        require(ISettingManager(_settings).canAddLiquidity(address(this),user),"user can not add liquidity");
        require(amount > 0, "added liquidity must > 0");
        rebase();

        uint256 lsTotalSupply = IERC20(address(this)).totalSupply();
        uint256 lsTokenAmount = Price.lsTokenByPoolToken(
            lsTotalSupply,
            _liquidityPool,
            amount
        );
        poolCallback(user, amount);

        _mint(user, lsTokenAmount);
        bytes memory eventData = abi.encode(address(0),user, lsTokenAmount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(10,eventData);

        _liquidityPool = _liquidityPool.add(amount);
        _lsAvgPrice = Price.calLsAvgPrice(_lsAvgPrice, lsTotalSupply, amount, lsTokenAmount);

        IDebt debt = IDebt(debtToken);
        uint bonds;
        if (lsTotalSupply > 0) {
            bonds = debt.bondsLeft().mul(lsTokenAmount) / lsTotalSupply;
            if (bonds > 0) {
                debt.issueBonds(user, bonds);
            }
        }
        eventData = abi.encode(user, amount, lsTokenAmount, bonds);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(2,eventData);
    }

    function removeLiquidity(address user, uint256 amount, uint256 bondsAmount, address receipt) external override lock {
        rebase();

        IERC20 ls = IERC20(address(this));
        uint256 bondsLeft = IDebt(debtToken).bondsLeft();
        uint256 poolTokenAmount;

        if (bondsAmount == 0) {
            poolTokenAmount = Price.poolTokenByLsTokenWithDebt(
                ls.totalSupply(),
                bondsLeft,
                _liquidityPool,
                amount
            );
        } else {
            uint256 bondsRequired = bondsLeft.mul(amount).div(ls.totalSupply());
            if (bondsAmount >= bondsRequired) {
                bondsAmount = bondsRequired;
            } else {
                amount = bondsAmount.mul(ls.totalSupply()).div(bondsLeft);
            }

            IPoolCallback(msg.sender).poolV2BondsCallback(
                bondsAmount,
                _poolToken,
                address(_oraclePool),
                user
            );

            IDebt(debtToken).burnBonds(bondsAmount);
            poolTokenAmount = Price.poolTokenByLsTokenWithDebt(
                ls.totalSupply(),
                0,
                _liquidityPool,
                amount
            );
        }

        uint256 nakedPosition = Price
            .mulPrice(_totalSizeLong.diff(_totalSizeShort), getPrice())
            .div(10**_poolDecimalDiff);
        require(!ISettingManager(_settings).reachLCoefficient(address(this),nakedPosition,poolTokenAmount),
            "liquidity less than naked positions");

        uint256 balanceBefore = ls.balanceOf(address(this));
        IPoolCallback(msg.sender).poolV2RemoveCallback(
            amount,
            _poolToken,
            address(_oraclePool),
            user
        );
        require(
            ls.balanceOf(address(this)) >=
                balanceBefore.add(amount),
            "LP Token is not enough"
        );

        _burn(address(this), amount);
        bytes memory eventData = abi.encode(address(this), address(0), amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(10,eventData);

        _liquidityPool = _liquidityPool.sub(poolTokenAmount);
        IERC20(_poolToken).safeTransfer(receipt, poolTokenAmount);
        eventData = abi.encode(user, poolTokenAmount, amount, bondsAmount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(3,eventData);
    }

    function openPosition(
        address user,
        uint8 direction,
        uint16 leverage,
        uint256 position
    ) external override returns (uint32) {
        require(ISettingManager(_settings).isPoolActive(address(this)),"pool is suspended");

        require(ISettingManager(_settings).checkOpenPosition(address(this),leverage),"invalid leverage");
        require(
            direction == 1 || direction == 2,
            "Direction Only Can Be 1 Or 2"
        );

        require(position > 0, "position must bigger than 0");
        require(_liquidityPool > 0, "liquidity pool must > 0");

        rebase();

        uint256 value = position.mul(leverage);
        uint256 price = ISettingManager(_settings).getDivationPrice(address(this),value,direction);

        poolCallback(user, position);
        if (_poolDecimalDiff > 0) {
            value = value.mul(10**_poolDecimalDiff);
        }
        uint256 size = Price.divPrice(value, price);

        uint256 openRebase;
        if (direction == 1) {
            _totalSizeLong = _totalSizeLong.add(size);
            openRebase = _rebaseAccumulatedLong;
        } else {
            _totalSizeShort = _totalSizeShort.add(size);
            openRebase = _rebaseAccumulatedShort;
        }

        _positionIndex++;
        _positions[_positionIndex] = Position(
            price,
            block.number,
            position,
            size,
            openRebase,
            msg.sender,
            direction
        );

        bytes memory eventData = abi.encode(user,
            price,
            openRebase,
            direction,
            leverage,
            position,
            size,
            _positionIndex);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(4,eventData);
        return _positionIndex;
    }

    function addMargin(
        address user,
        uint32 positionId,
        uint256 margin
    ) external override {
        require(ISettingManager(_settings).isPoolActive(address(this)),"pool is suspended");
        Position memory p = _positions[positionId];
        require(msg.sender == p.account, "Position Not Match");
        rebase();

        poolCallback(user, margin);
        _positions[positionId].margin = p.margin.add(margin);
        bytes memory eventData = abi.encode(user, margin, positionId);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(5,eventData);
    }

    function closePosition(
        address receipt,
        uint32 positionId
    ) external override {
        require(ISettingManager(_settings).isPoolActive(address(this)),"pool is suspended");

        Position memory p = _positions[positionId];
        require(p.account == msg.sender, "Position Not Match");
        rebase();

       
        int256 debtChange;
        (uint256 transferOut,uint256 pnl,uint256 fee,uint256 fundingFee,bool isProfit) = getPositionValue(positionId);
        require(
            !ISettingManager(_settings).isPositionLiq(address(0),transferOut,p.margin),
            "Bankrupted Liquidation"
        );
        if (transferOut < p.margin) {
            uint256 debtRepay = ISettingManager(_settings).getDebtRepay(address(this),p.margin.sub(transferOut));
            if (debtRepay > 0) {
                IERC20(_poolToken).safeTransfer(debtToken, debtRepay);
            }

            debtChange = int256(-debtRepay);

        } else {

            uint256 debtIssue = ISettingManager(_settings).getDebtIssue(address(this),transferOut.sub(p.margin));

            transferOut = transferOut.sub(debtIssue);
            if (debtIssue > 0) {
                IDebt(debtToken).issueBonds(receipt, debtIssue);
            }

            debtChange = int256(debtIssue);
        }

        if (transferOut > _liquidityPool.add(p.margin)) {
            transferOut = _liquidityPool.add(p.margin);
        }

        if (transferOut > 0) {
            IERC20(_poolToken).safeTransfer(receipt, transferOut);
        }

        if (p.margin >= transferOut.add(Price.calRepay(debtChange))) {
            _liquidityPool = _liquidityPool.add(p.margin.sub(transferOut.add(Price.calRepay(debtChange))));
        } else {
            _liquidityPool = _liquidityPool.sub(transferOut.add(Price.calRepay(debtChange)).sub(p.margin));
        }

        _mintLsByPoolToken(ISettingManager(_settings).getProtocolFee(fee.add(fundingFee)));

        delete _positions[positionId];

        bytes memory eventData = abi.encode(receipt,
            getPrice(),
            fee,
            fundingFee,
            pnl,
            positionId,
            isProfit,
            debtChange);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(6,eventData);
    }

    function liquidate(
        address user,
        uint32 positionId,
        address receipt
    ) external override {
        Position memory p = _positions[positionId];
        require(p.account != address(0), "Position Not Match");

        require(ISettingManager(_settings).isPoolActive(address(this)),"pool is suspended");
        require(ISettingManager(_settings).reachLsRequire(address(this),user), "Not Meet Min Ls Amount");

        rebase();

        (uint256 transferOut,uint256 pnl,uint256 fee,uint256 fundingFee,bool isProfit) = getPositionValue(positionId);
        require(
            ISettingManager(_settings).isPositionLiq(address(this),transferOut,p.margin),
            "Position Cannot Be Liquidated by Not Meet MarginRatio"
        );

        uint256 liquidateFee =  ISettingManager(_settings).calLiquidateFee(address(this),p.margin,p.openBlock);
        uint256 liqProtocolFee =  ISettingManager(_settings).getProtocolFee(liquidateFee);
        liquidateFee = liquidateFee.sub(liqProtocolFee);

        uint256 debtRepay = ISettingManager(_settings).getDebtRepay(address(this),p.margin.sub(liquidateFee));
        if (debtRepay > 0) {
            IERC20(_poolToken).safeTransfer(debtToken, debtRepay);
        }

        _liquidityPool = _liquidityPool.add(p.margin.sub(liquidateFee).sub(debtRepay));
        IERC20(_poolToken).safeTransfer(receipt, liquidateFee);
        delete _positions[positionId];

        uint256 protocolFee = ISettingManager(_settings).getProtocolFee(fundingFee.add(fee));
        _mintLsByPoolToken(protocolFee.add(liqProtocolFee));
        bytes memory eventData = abi.encode(user,
            positionId,
            getPrice(),
            fee,
            fundingFee,
            liquidateFee,
            pnl,
            isProfit,
            debtRepay);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(7,eventData);
    }

    function getPositionValue(uint32 positionID) internal returns (uint256 transferOut,uint256 pnl,uint256 fee,uint256 fundingFee,bool isProfit){
        Position memory p = _positions[positionID];
        uint256 poolDecimalDiff = StandardDecimal > ERC20(_poolToken).decimals()
            ? StandardDecimal - ERC20(_poolToken).decimals()
            : 0;

        uint256 closePrice = getPrice();
        pnl = Price.mulPrice(p.size, closePrice.diff(p.openPrice));
        fee = ISettingManager(_settings).getCloseFee(address(this),Price.mulPrice(p.size, closePrice),p.openBlock);
        fundingFee;

        if (p.direction == 1) {
            fundingFee = Price.calFundingFee(
                p.size.mul(_rebaseAccumulatedLong.sub(p.openRebase)),
                closePrice
            );

            _totalSizeLong = _totalSizeLong.sub(p.size);
        } else {
            fundingFee = Price.calFundingFee(
                p.size.mul(_rebaseAccumulatedShort.sub(p.openRebase)),
                closePrice
            );

            _totalSizeShort = _totalSizeShort.sub(p.size);
        }

        if (poolDecimalDiff != 0) {
            pnl = pnl.div(10**poolDecimalDiff);
            fee = fee.div(10**poolDecimalDiff);
            fundingFee = fundingFee.div(10**poolDecimalDiff);
        }

        isProfit = (closePrice >= p.openPrice) == (p.direction == 1);

        transferOut = isProfit.addOrSub2Zero(p.margin, pnl).sub2Zero(fee).sub2Zero(
            fundingFee
        );
    }

    function rebase() internal {
        (uint256 rebaseLongDelta ,uint256 rebaseShortDelta) = ISettingManager(_settings).calRebaseDelta(address(this));
        _rebaseAccumulatedLong = _rebaseAccumulatedLong.add(rebaseLongDelta);
        _rebaseAccumulatedShort = _rebaseAccumulatedShort.add(rebaseShortDelta);
        _lastRebaseBlock = block.number;
        bytes memory eventData = abi.encode(            
            _rebaseAccumulatedLong,
            _rebaseAccumulatedShort);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(8,eventData);

    }
    function exit(
        address receipt,
        uint32 positionId
    ) external override {
        require(!ISettingManager(_settings).isPoolActive(address(this)),"pool is active");

        Position memory p = _positions[positionId];
        require(p.account == msg.sender, "P Err");

        if (p.direction == 1) {
            _totalSizeLong = _totalSizeLong.sub(p.size);
        } else {
            _totalSizeShort = _totalSizeShort.sub(p.size);
        }

        IERC20(_poolToken).safeTransfer(receipt, p.margin);

        delete _positions[positionId];

        bytes memory eventData = abi.encode(positionId,receipt);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(9,eventData);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        bytes memory eventData = abi.encode(_msgSender(), recipient, amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(10,eventData);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender,_msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        bytes memory eventData = abi.encode(sender, recipient, amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(10,eventData);
        return true;
    }
}
