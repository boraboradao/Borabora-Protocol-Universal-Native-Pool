pragma solidity 0.7.6;

interface IDebt {

    function owner() external view returns (address);

    function issueBonds(address recipient, uint256 amount) external;

    function burnBonds(uint256 amount) external;

    function repayLoan(address payer, address recipient, uint256 amount) external;

    function totalDebt() external view returns (uint256);

    function bondsLeft() external view returns (uint256);

    // struct PTransfer{address from;address to;uint256 amount;}

    // struct RepayLoan{
    //     address receipt;
    //     uint256 bondsTokenAmount;
    //     uint256 poolTokenAmount;
    // }
}
