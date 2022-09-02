pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISetting.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IEventOut.sol";

import "./libraries/BasicMaths.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./libraries/Price.sol";



contract PoolSetting is ISetting, Ownable {
    using SafeMath for uint256;
    using BasicMaths for uint256;

    uint256 private constant E4 = 1e4;


    enum systemParam {
        MarginRatio,
        ClosingFee,
        LiqFeeBase,
        LiqFeeMax,
        LiqFeeCoefficient,
        RebaseCoefficient,
        ImbalanceThreshold,
        MinHoldingPeriod,
        MinOpenPosition,
        MinHoldCloseFee,
        ProhibitOpenDelta,
        Other
    }

    // event AddLeverage(uint16 leverage);
    // event DeleteLeverage(uint16 leverage);
    // struct SetParam{systemParam param; uint256 value;}
    // event SetDeviation(bool deviation);
    // event SetActive(bool active);
    // struct SetLadderDivation{uint256 key;uint256 value;uint256 next;}

    struct LadderDeviation {
        uint256 deviationRate;
        uint256 next;
    }

    mapping(uint16 => bool) public _leverages;
    // mapping(address => address) public _poolSetting;
    mapping(uint256 => LadderDeviation) public _ladderDeviation;

    bool public _acive;
    bool public _deviate;
    uint256 public _minHoldingPeriod;
    uint256 public _closeRate;
    uint256 public _minHoldCloseRate;
    uint256 public _marginRatio;

    uint256 public _liqFeeBase;
    uint256 public _liqFeeMax;
    uint256 public _liqFeeCoefficient;
    uint256 public _imbalanceThreshold;
    uint256 public _rebaseSizeXBlockDelta;
    uint256 public _minOpenAmount;
    uint256 public _prohibitOpenDelta;

    address public _eventOut;
    bool public _limitLPUser = false;
    mapping(address => bool) _activeLPUser;

    function setEventOut(address eventAddress) public onlyOwner {
        _eventOut = eventAddress;
    }

    function getSystemParam() public view returns (uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256)
    {
        return (_minHoldingPeriod,
                _closeRate,
                _minHoldCloseRate,
                _marginRatio,
                _liqFeeBase,
                _liqFeeMax,
                _liqFeeCoefficient,
                _imbalanceThreshold,
                _rebaseSizeXBlockDelta,
                _minOpenAmount);
    }

    function addLeverage(uint16 leverage) external onlyOwner {
        _leverages[leverage] = true;
        bytes memory eventData = abi.encode(leverage);
        IEventOut(_eventOut).eventOut(1,eventData);
        // emit AddLeverage(leverage);
    }

    function deleteLeverage(uint16 leverage) external onlyOwner {
        _leverages[leverage] = false;
        bytes memory eventData = abi.encode(leverage);
        IEventOut(_eventOut).eventOut(2,eventData);
        // emit DeleteLeverage(leverage);
    }

    function setLimitLpUser(bool limitLPUSer) public onlyOwner {
        _limitLPUser = limitLPUSer;
        bytes memory eventData = abi.encode(limitLPUSer);
        IEventOut(_eventOut).eventOut(8,eventData);
    }

    function addLpUser(address newLpUser) public onlyOwner {
        _activeLPUser[newLpUser] = true;
        bytes memory eventData = abi.encode(newLpUser);
        IEventOut(_eventOut).eventOut(9,eventData);
    }

    function deleteLpUser(address lpUser) public onlyOwner {
        _activeLPUser[lpUser] = false;
        bytes memory eventData = abi.encode(lpUser);
        IEventOut(_eventOut).eventOut(10,eventData);  
    }

    function setProhibitOpenDelta(uint256 prohibitOpenDelta) public onlyOwner {
        _prohibitOpenDelta = prohibitOpenDelta;
        // SetParam memory _param = SetParam(systemParam.MinOpenPosition,minOpenAmount);
         bytes memory eventData = abi.encode(systemParam.ProhibitOpenDelta,prohibitOpenDelta);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.MinOpenPosition,minOpenAmount);

    }

    function setMinOpenAmount(uint256 minOpenAmount) public onlyOwner {
        _minOpenAmount = minOpenAmount;
        // SetParam memory _param = SetParam(systemParam.MinOpenPosition,minOpenAmount);
         bytes memory eventData = abi.encode(systemParam.MinOpenPosition,minOpenAmount);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.MinOpenPosition,minOpenAmount);

    }

    function setRebaseXBlockDelta(uint256 rebaseXBlockDelta) public onlyOwner {
        _rebaseSizeXBlockDelta = rebaseXBlockDelta;

        // SetParam memory _param = SetParam(systemParam.RebaseCoefficient,rebaseXBlockDelta);
         bytes memory eventData = abi.encode(systemParam.RebaseCoefficient,rebaseXBlockDelta);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.RebaseCoefficient,rebaseXBlockDelta);
    }

    function setImbalanceThreshold(uint256 imbalanceThreshold) public onlyOwner {
        _imbalanceThreshold = imbalanceThreshold;

        // SetParam memory _param = SetParam(systemParam.ImbalanceThreshold,imbalanceThreshold);
         bytes memory eventData = abi.encode(systemParam.ImbalanceThreshold,imbalanceThreshold);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.ImbalanceThreshold,imbalanceThreshold);

    }

    function setLiqFeeBase(uint256 liqFeeBase) public onlyOwner {
        _liqFeeBase = liqFeeBase;
        // SetParam memory _param = SetParam(systemParam.LiqFeeBase,liqFeeBase);
         bytes memory eventData = abi.encode(systemParam.LiqFeeBase,liqFeeBase);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.LiqFeeBase,liqFeeBase);
    }

    function setLiqFeeMax(uint256 liqFeeMax) public onlyOwner {
        _liqFeeMax = liqFeeMax;
        // SetParam memory _param = SetParam(systemParam.LiqFeeMax,liqFeeMax);
         bytes memory eventData = abi.encode(systemParam.LiqFeeMax,liqFeeMax);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.LiqFeeMax,liqFeeMax);
    }

    function setLiqFeeCoefficient(uint256 liqFeeCoefficient) public onlyOwner {
        _liqFeeCoefficient = liqFeeCoefficient;
        // SetParam memory _param = SetParam(systemParam.LiqFeeCoefficient,liqFeeCoefficient);
         bytes memory eventData = abi.encode(systemParam.LiqFeeCoefficient,liqFeeCoefficient);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.LiqFeeCoefficient,liqFeeCoefficient);
    }

    function setMarginRatio(uint256 marginRatio) public onlyOwner {
        _marginRatio = marginRatio;
        // SetParam memory _param = SetParam(systemParam.MarginRatio,marginRatio);
         bytes memory eventData = abi.encode(systemParam.MarginRatio,marginRatio);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.MarginRatio,marginRatio);
    }

    function setMinHoldCloseRate(uint256 minHoldCloseRate) public onlyOwner {
        _minHoldCloseRate = minHoldCloseRate;
        // SetParam memory _param = SetParam(systemParam.MinHoldCloseFee,minHoldCloseRate);
         bytes memory eventData = abi.encode(systemParam.MinHoldCloseFee,minHoldCloseRate);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.MinHoldCloseFee,minHoldCloseRate);
    }

    function setCloseRate(uint256 closeRate) public onlyOwner {
        _closeRate = closeRate;
        // SetParam memory _param = SetParam(systemParam.ClosingFee,closeRate);
         bytes memory eventData = abi.encode(systemParam.ClosingFee,closeRate);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.ClosingFee,closeRate);
    }

    function setMinHoldingPeriod(uint256 minHoldingPeriod) public onlyOwner {
        _minHoldingPeriod = minHoldingPeriod;
        // SetParam memory _param = SetParam(systemParam.MinHoldingPeriod,minHoldingPeriod);
         bytes memory eventData = abi.encode(systemParam.MinHoldingPeriod,minHoldingPeriod);
         IEventOut(_eventOut).eventOut(3,eventData);
        // emit SetParam(systemParam.MinHoldingPeriod,minHoldingPeriod);
    }

    function setDeviate(bool deviate) public onlyOwner {
        _deviate = deviate;
        bytes memory eventData = abi.encode(deviate);
         IEventOut(_eventOut).eventOut(4,eventData);
        // emit SetDeviation(deviate);
    }

    function setPoolActive(bool active) public onlyOwner {
        _acive = active;
        bytes memory eventData = abi.encode(active);
         IEventOut(_eventOut).eventOut(5,eventData);
        // emit SetActive(active);
    }

    function setLadderDeviation(uint256 key,uint256 dR,uint256 nt) public onlyOwner {
        require (nt > key,"wrong next");
        LadderDeviation memory ladderDeviation = _ladderDeviation[key];
        ladderDeviation.deviationRate = dR;
        ladderDeviation.next = nt;
        _ladderDeviation[key] = ladderDeviation;

        // SetLadderDivation memory _param = SetLadderDivation(key,dR,nt);
        bytes memory eventData = abi.encode(key,dR,nt);
         IEventOut(_eventOut).eventOut(7,eventData);
        // emit SetLadderDivation(key,dR,nt);

    }

    function canAddLiquidity(address poolAddress,address user) external override view returns(bool) {
        if (!_limitLPUser) {
            return true;
        }
        return _activeLPUser[user];
    }

    // 判断杠杆是否合理
    function checkOpenPosition(uint16 level) external override view  returns (bool) {
        return _leverages[level];
    }
    // 池子是否被激活,激活状态下可以做任何操作，其他状态只能退出
    function isPoolActive() external override view returns (bool)
    {
        return _acive;
    }

    // 是否到流动性保护系数
    // function reachLCoefficient(address poolAddress,int256 nakedPosition,uint256 liquidityPool) external view returns (bool);
    function reachLCoefficient(address poolAddress,uint256 nakedPosition,uint256 removeLiquidity) external override view returns (bool) {
        uint256 liquidityPool = IPool(poolAddress)._liquidityPool();
        if (liquidityPool < removeLiquidity) {
            return true;
        }
        return nakedPosition > liquidityPool.sub(removeLiquidity);
    }
    // 获得偏移以后的价格 只和开仓头寸有关 稍后整理把
    function getDivationPrice(address poolAddress,uint256 position,uint8 direction) external override view returns (uint256) {
        uint256 price = IPool(poolAddress).getPrice();
        if (!_deviate) {
            return price;
        }

        //判断是否超过相关开仓上限  position是杠杆以后的
        require(!reachPODelta(poolAddress,position,direction),"Error Reach Divation Upper Limit");
        uint256 key = 1;
        uint256 next = _ladderDeviation[key].next;
        while (next < position) {
            key = next;
            next = _ladderDeviation[key].next;
        }

        if (direction == 1) {
            return price.add(price.mul(_ladderDeviation[key].deviationRate).div(E4));
        } else {
            return price.sub(price.mul(_ladderDeviation[key].deviationRate).div(E4));
        }
    }

    function reachPODelta(address poolAddress,uint256 position,uint8 direction) internal view returns (bool) {
        uint256 currentPrice = IPool(poolAddress).getPrice();
        uint256 totalSizeLong = IPool(poolAddress)._totalSizeLong();
        uint256 totalSizeShort = IPool(poolAddress)._totalSizeShort();
        uint256 poolDecimalDiff = IPool(poolAddress)._poolDecimalDiff();
        uint256 liquidityPool = IPool(poolAddress)._liquidityPool();


        uint256 nakedPosition = Price
            .mulPrice(totalSizeLong.diff(totalSizeShort), currentPrice)
            .div(10**poolDecimalDiff);

        if ((direction == 1) == (totalSizeLong > totalSizeShort)) {//这一步有问题，第一笔判断有问题
            nakedPosition = nakedPosition.add(position);
        } else if(totalSizeLong == totalSizeShort){
            nakedPosition = position;
        } else {
            return false;
        }
        
        if (nakedPosition > liquidityPool.mul(_prohibitOpenDelta).div(E4)) {
            return true;
        }

        return false;
    }
    // 获取服务费
    function getCloseFee(address poolAddress,uint256 position,uint256 openBlock) external override view returns (uint256) { 
        if (block.number.sub(openBlock) < _minHoldingPeriod) {
            return position.mul(_minHoldCloseRate).div(E4);
        }
        return position.mul(_closeRate).div(E4);
    }
    // 债务相关  还债
    function getDebtRepay(address poolAddress,uint256 transferIn) external override view returns (uint256) {
        return 0;
    }
    // 需要还多少债务
    function getDebtIssue(address poolAddress,uint256 transferOut) external override view returns (uint256) {
        return 0;
    }

    // 清算需要持有多少LP代币？  默认不收取
    function reachLsRequire(address poolAddress,address user) external override view returns (bool) {
        return true;
    }
    // 是否达到清算线？
    function isPositionLiq(address poolAddress,uint256 transferOut,uint256 margin) external override view returns (bool) {
        return transferOut < margin.mul(_marginRatio).div(E4);
    }
    // 计算清算奖励
    function calLiquidateFee(address poolAddress,uint256 margin,uint256 openBlock) external override view returns (uint256) { 
        if (_liqFeeBase == _liqFeeMax) {
            return _liqFeeBase.mul(margin) / E4;
        }

        uint256 liqRatio = block.number.sub(openBlock).mul(_liqFeeMax.sub(_liqFeeBase)) / _liqFeeCoefficient + _liqFeeBase;
        if (liqRatio < _liqFeeMax) {
            return liqRatio.mul(margin) / E4;
        } else {
            return _liqFeeMax.mul(margin) / E4;
        }
    }

    function mulInterestFromDebt(address poolAddress,uint256 amount) external override view returns(uint256) {
        return amount;          
    }

    function divInterestFromDebt(
        address poolAddress,
        uint256 amount
    ) external override view returns (uint256) {
        return amount;
    }
    // Rebase的比例计算  是否搞一个结构体？
    function calRebaseDelta(address poolAddress) external override view returns (uint256,uint256) { 
        uint256 lastRebaseBlock = IPool(poolAddress)._lastRebaseBlock();
        if (lastRebaseBlock >= block.number) {
            return (0,0);
        }
        uint256 liquidityPool = IPool(poolAddress)._liquidityPool();
        if (liquidityPool == 0) {
            return (0,0);
        }
        uint256 rebasePrice = IPool(poolAddress).getPrice();
        uint256 totalSizeLong = IPool(poolAddress)._totalSizeLong();
        uint256 totalSizeShort = IPool(poolAddress)._totalSizeShort();
        uint256 poolDecimalDiff = IPool(poolAddress)._poolDecimalDiff();

        uint256 nakedPosition = Price
            .mulPrice(totalSizeLong.diff(totalSizeShort), rebasePrice)
            .div(10**poolDecimalDiff);
        
        if (nakedPosition < liquidityPool.mul(_imbalanceThreshold).div(E4)) {
            return (0,0);
        }

        uint256 rebasePosition = nakedPosition.sub(liquidityPool.mul(_imbalanceThreshold).div(E4));

        if (totalSizeLong > totalSizeShort) {
            return (rebasePosition.mul(block.number.sub(lastRebaseBlock)).mul(1e18)
            .div(totalSizeLong.mul(rebasePrice).mul(_rebaseSizeXBlockDelta).div(10**poolDecimalDiff).div(1e18)),0);
        } else {
            return (0,rebasePosition.mul(block.number.sub(lastRebaseBlock)).mul(1e18)
            .div(totalSizeShort.mul(rebasePrice).mul(_rebaseSizeXBlockDelta).div(10**poolDecimalDiff).div(1e18)));
        }

    }
    // 最小开仓额的计算
    function reachMinOpenAmount(address poolAddress,uint256 nakePosition) external override view returns (bool) { 
        return _minOpenAmount < nakePosition;
    }

}