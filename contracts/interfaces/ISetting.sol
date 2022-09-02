pragma solidity 0.7.6;
// 能从msg.sender中获取就从msg.sender中获取,
// 如果是PSManager去调用则没办法直接获取相关参数，很多内容需要把池子地址传进去，稍后补充
interface ISetting {

    // 判断杠杆是否合理
    function checkOpenPosition(uint16 level) external view returns (bool);
    // 池子是否被激活,激活状态下可以做任何操作，其他状态只能退出
    function isPoolActive() external view returns (bool);

    // 是否到流动性保护系数
    function reachLCoefficient(address poolAddress,uint256 nakedPosition,uint256 removeLiquidity) external view returns (bool);
    // 获得偏移以后的价格 只和开仓头寸有关
    function getDivationPrice(address poolAddress,uint256 position,uint8 direction) external view returns (uint256);
    // 获取服务费
    function getCloseFee(address poolAddress,uint256 position,uint256 openBlock) external view returns (uint256);
    // 债务相关  需要借多少债务
    function getDebtRepay(address poolAddress,uint256 transferIn) external view returns (uint256);
    // 需要还多少债务
    function getDebtIssue(address poolAddress,uint256 transferOut) external view returns (uint256);

    // 清算需要持有多少LP代币？
    function reachLsRequire(address poolAddress,address user) external view returns (bool);
    // 是否达到清算线？
    function isPositionLiq(address poolAddress,uint256 transferOut,uint256 margin) external view returns (bool);
    // 计算清算奖励
    function calLiquidateFee(address poolAddress,uint256 margin,uint256 openBlock) external view returns (uint256);
    // Rebase的比例计算
    function calRebaseDelta(address poolAddress) external view returns (uint256,uint256);
    // 最小开仓额的计算
    function reachMinOpenAmount(address poolAddress,uint256 nakePosition) external view returns (bool);
    function mulInterestFromDebt(address poolAddress,uint256 amount) external view returns(uint256);
    function canAddLiquidity(address poolAddress,address user) external view returns(bool);

    function divInterestFromDebt(
        address poolAddress,
        uint256 amount
    ) external view returns (uint256);

}