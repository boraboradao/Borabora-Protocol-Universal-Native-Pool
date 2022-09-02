pragma solidity 0.7.6;

interface IPool {
    struct Position {
        uint256 openPrice;
        uint256 openBlock;
        uint256 margin;
        uint256 size;
        uint256 openRebase;
        address account;
        uint8 direction;
    }

    function _positions(uint32 positionId)
        external
        view
        returns (
            uint256 openPrice,
            uint256 openBlock,
            uint256 margin,
            uint256 size,
            uint256 openRebase,
            address account,
            uint8 direction
        );
    function _liquidityPool() external view returns (uint256 );

    function _totalSizeLong() external view returns (uint256 );
    function _totalSizeShort() external view returns (uint256 );
    function _lastRebaseBlock() external view returns (uint256 );
    function _poolDecimalDiff() external view returns (uint256 );

    function getPrice() external view returns(uint256);
    function debtToken() external view returns (address);

    function lsTokenPrice() external view returns (uint256);

    function addLiquidity(address user, uint256 amount) external;

    function removeLiquidity(address user, uint256 lsAmount, uint256 bondsAmount, address receipt) external;

    function openPosition(
        address user,
        uint8 direction,
        uint16 leverage,
        uint256 position
    ) external returns (uint32);

    function addMargin(
        address user,
        uint32 positionId,
        uint256 margin
    ) external;

    function closePosition(
        address receipt,
        uint32 positionId
    ) external;

    function liquidate(
        address user,
        uint32 positionId,
        address receipt
    ) external;

    function _poolToken() external view returns (address);

    function exit(
        address receipt,
        uint32 positionId
    ) external;

    // struct MintLiquidity(uint256 amount);

    // struct AddLiquidity{
    //     address  sender;
    //     uint256 amount;
    //     uint256 lsAmount;
    //     uint256 bonds;
    // }

    // struct RemoveLiquidity{
    //     address  sender;
    //     uint256 amount;
    //     uint256 lsAmount;
    //     uint256 bondsRequired;
    // }

    // struct OpenPosition{
        // address  sender;
        // uint256 openPrice;
        // uint256 openRebase;
        // uint8 direction;
        // uint16 level;
        // uint256 margin;
        // uint256 size;
        // uint32 positionId;
    // }

    // struct AddMargin{
    //     address  sender;
    //     uint256 margin;
    //     uint32 positionId;
    // }

    // struct ClosePosition{
    //     address  receipt;
    //     uint256 closePrice;
    //     uint256 serviceFee;
    //     uint256 fundingFee;
    //     uint256 pnl;
    //     uint32  positionId;
    //     bool isProfit;
    //     int256 debtChange;
    // }

    // struct Liquidate{
    //     address  sender;
    //     uint32 positionID;
    //     uint256 liqPrice;
    //     uint256 serviceFee;
    //     uint256 fundingFee;
    //     uint256 liqReward;
    //     uint256 pnl;
    //     bool isProfit;
    //     uint256 debtRepay;
    // }

    // struct Rebase{ uint256 rebaseAccumulatedLong; uint256 rebaseAccumulatedShort;}

    // struct Exit{uint256 positionId;address receipt;}

    // struct PTransfer{address from;address to;uint256 amount;}
}
