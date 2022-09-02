pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract mockToken is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimal,
        uint256 amount
    ) ERC20(name_, symbol_) {
        _setupDecimals(decimal);
        _mint(msg.sender, amount);
    }
    function mintTest(uint256 amount)external  {
        _mint(msg.sender, amount);
    }
}
