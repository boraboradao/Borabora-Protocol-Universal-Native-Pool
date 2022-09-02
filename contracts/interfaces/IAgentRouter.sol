pragma solidity 0.7.6;
pragma abicoder v2;
// import "./IRouter.sol";


interface IAgentRouter {
    //返佣关系建立的event  第一个参数是调用者，第二个参数是调用者的上级
    struct RelationCreate{address sender; address upAddress;}

    enum AgentParam {
        OwnerRate,
        ContributeRate,
        SecondUpperRate,
        ExecPreBillAmount,
        ExecPositionAmount
    }


    struct strategy {
        uint32 strategyType;
        uint256 value;
    }


    // struct StrategySheet{uint32 tokenId;uint32 strategyType;uint256 value;}

    // struct TokenCreate{uint32 tokenId; address pool; address sender; uint32 positionId;
    //     address excutorAddress;}

    // struct SetAgentParam{AgentParam paramType;uint256 paramValue;}

    // struct AddContribute{address user;address token;uint256 amount;}

    // struct ClaimContribute{address user;address token;}

    // //预埋单的Event
    // struct OpenPreBill{
    //     address owner;
    //     uint32 tokenId;
    //     address poolAddress;      
    //     uint8 direction;
    //     uint16 leverage;
    //     uint256 position;
    //     address excutorAddress;
    // }

    // // struct CancleBill{uint32 tokenId}

    // struct SetExecutor{uint32 tokenId;address executor;}

    // struct ExecPreBill{uint32 tokenId;address executor;}
    //设置各种参数的Event
    //返佣的event
    //埋单的event

    function openPreBill(
        address oracleAddress,
        address poolToken,
        uint8 direction,
        uint16 leverage,
        uint256 position,
        address excutorAddress,
        strategy[] memory strategyDatas) external payable;

    
    function setExecutor(
        uint32 tokenId,
        uint8 billType,
        address executor
    ) external  payable;

    function execPreBill(uint32 tokenId) external ;

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
        uint256 position,
        address excutorAddress,
        strategy[] memory strategyDatas
    ) external payable;

    function addMargin(uint32 tokenId, uint256 margin) external payable;

    function closeAgentPosition(uint32 tokenId) external;

    function liquidate(uint32 tokenId, address receipt) external;

    function liquidateByPool(address poolAddress, uint32 positionId, address receipt) external;

    function exit(uint32 tokenId, address receipt) external;

    function repayLoan(
        address oracleAddress,
        address poolToken,
        uint256 amount,
        address receipt
    ) external payable;
}
