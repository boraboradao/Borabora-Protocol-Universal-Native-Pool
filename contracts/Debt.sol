pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IDebt.sol";
import "./interfaces/IRates.sol";
import "./interfaces/IPoolCallback.sol";
// import "./interfaces/ISystemSettings.sol";
import "./interfaces/ISettingManager.sol";

import "./libraries/BasicMaths.sol";
import "./interfaces/IEventOut.sol";


contract Debt is ERC20, IDebt {
    using SafeMath for uint256;
    using BasicMaths for uint256;
    using SafeERC20 for IERC20;

    address public _poolToken;
    address public _settings;
    address private _owner;

    constructor(
        address owner_,
        address poolToken,
        address setting,
        string memory symbol
    ) ERC20(symbol, symbol) {
        _setupDecimals(ERC20(poolToken).decimals());

        _owner = owner_;
        _poolToken = poolToken;
        _settings = setting;
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function issueBonds(address recipient, uint256 amount) external override onlyOwner {
        _mint(recipient, amount);

        // PTransfer memory _data = PTransfer(address(0), recipient, amount);
        bytes memory eventData = abi.encode(address(0), recipient, amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(1,eventData);
    }

    function burnBonds(uint256 amount) external override onlyOwner {
        _burn(address(this), amount);

        // PTransfer memory _data = PTransfer(address(this), address(0), amount);
        bytes memory eventData = abi.encode(address(this), address(0), amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(1,eventData);
    }

    // call from router
    function repayLoan(address payer, address recipient, uint256 amount) external override {

        IRates pool = IRates(_owner);
        IPoolCallback(msg.sender).poolV2BondsCallbackFromDebt(
            amount,
            _poolToken,
            pool.oraclePool(),
            payer
        );

        _burn(address(this), amount);
        // PTransfer memory _Tdata = PTransfer(address(this), address(0), amount);
        bytes memory eventData = abi.encode(address(this), address(0), amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(1,eventData);

        uint256 poolTokenAmount = ISettingManager(_settings).mulInterestFromDebt(_owner,amount);
        require(poolTokenAmount <= IERC20(_poolToken).balanceOf(address(this)), "Insufficient token to repay loan");
        IERC20(_poolToken).safeTransfer(recipient, poolTokenAmount);
        // RepayLoan memory _data = RepayLoan(recipient, amount, poolTokenAmount);
        eventData = abi.encode(recipient, amount, poolTokenAmount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(2,eventData);
    }

    function totalDebt() external override view returns (uint256) {
        return ISettingManager(_settings).mulInterestFromDebt(_owner,totalSupply()).
        sub2Zero(IERC20(_poolToken).balanceOf(address(this)));
    }

    function bondsLeft() external override view returns (uint256) {
        return totalSupply().sub2Zero(
            ISettingManager(_settings).divInterestFromDebt(
                _owner,
                IERC20(_poolToken).balanceOf(address(this))
            )
        );
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        // PTransfer memory _data = PTransfer(_msgSender(), recipient, amount);
        bytes memory eventData = abi.encode(_msgSender(), recipient, amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(1,eventData);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender,_msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        // PTransfer memory _data = PTransfer(sender, recipient, amount);
        bytes memory eventData = abi.encode(sender, recipient, amount);
        IEventOut(ISettingManager(_settings).eventOut()).eventOut(1,eventData);
        return true;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "caller is not the owner");
        _;
    }
}
