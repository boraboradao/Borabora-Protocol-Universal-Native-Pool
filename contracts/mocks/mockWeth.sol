pragma solidity =0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract mockWeth is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimal,
        uint256 amount
    ) ERC20(name_, symbol_) {
        _setupDecimals(decimal);
        _mint(msg.sender, amount);
    }
 

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint amount) external {
        _burn(msg.sender,amount);
        Address.sendValue(msg.sender, amount);
    }

    // function transfer(address to, uint value) external returns (bool) {
    //     _transfer(_msgSender(), to, value);
    //     return true;
    // }

}
