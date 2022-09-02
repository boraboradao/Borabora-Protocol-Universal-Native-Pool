pragma solidity =0.7.6;

import "@chainlink/contracts/src/v0.5/interfaces/AggregatorV2V3Interface.sol";


contract mockAggent is AggregatorV2V3Interface  {
    constructor(
    )  {
_price = 1;
_decimal = 1;
    }

    uint256 public _price;
    uint8 public _decimal;
    function latestAnswer() external override view returns (int256){
        return int256(_price);
    }
    function latestTimestamp() external override view returns (uint256) {
        return _price;
    }
    function latestRound() external override view returns (uint256) {
        return _price;
    }
    function getAnswer(uint256 roundId) external override view returns (int256) {
        return int256(_price);
    }
    function getTimestamp(uint256 roundId) external override view returns (uint256) {
        return _price;
    }

    // event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 timestamp);
    // event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);

    //
    // V3 Interface:
    //
    function decimals() external override view returns (uint8) {
        return _decimal;
    }
    function description() external override view returns (string memory) {
        return "just for test";
    }
    function version() external override view returns (uint256) {
        return 1;
    }

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external override
        view
        returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
        )
         {
                return (1,2,3,4,5);
         }
    function latestRoundData()
        external override
        view
        returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
        )
        {
            return (1,2,3,4,5);
        }
    function setPrice(uint256 price,uint8 decimal)external  {
        _price = price;
        _decimal = decimal;
    }
}
