pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// SushiBar 合约 地址:0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272
contract SushiBar is ERC20("SushiBar", "xSUSHI"){
    using SafeMath for uint256;
    IERC20 public sushi;

    /**
    * @dev 构造函数
    * @param _sushi Sushi Token地址
     */
    constructor(IERC20 _sushi) public {
        sushi = _sushi;// 0x6b3595068778dd592e39a122f4f5a5cf09c90fe2
    }

    /**
    * @dev 进入吧台,将自己的SushiToken发送到合约换取份额
    * @param _amount SushiToken数额
     */
    // 进入吧台, 支付一些Sushi, 赚取份额
    // Enter the bar. Pay some SUSHIs. Earn some shares.
    function enter(uint256 _amount) public {
        // 当前合约的sushiToken余额
        uint256 totalSushi = sushi.balanceOf(address(this));
        // 当前合约的总发行量
        uint256 totalShares = totalSupply();
        // 如果 当前合约的总发行量 == 0 || 当前合约的总发行量 == 0
        if (totalShares == 0 || totalSushi == 0) {
            // 当前合约铸造amount数量的token给调用者
            _mint(msg.sender, _amount);
        } else {
            // what数额 = 数额 * 当前合约的总发行量 / 当前合约的sushiToken余额
            uint256 what = _amount.mul(totalShares).div(totalSushi);
            // 当前合约铸造what数量的token给调用者
            _mint(msg.sender, what);
        }
        // 将amount数量的sushi Token从调用者发送到当前合约地址
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    /**
    * @dev 离开吧台,取回自己的SushiToken
    * @param _share SUSHIs数额
     */
    // Leave the bar. Claim back your SUSHIs.
    function leave(uint256 _share) public {
        // 当前合约的总发行量
        uint256 totalShares = totalSupply();
        // what数额 = 份额 * 当前合约在sushiToken的余额 / 当前合约的总发行量
        uint256 what = _share.mul(sushi.balanceOf(address(this))).div(totalShares);
        // 为调用者销毁份额
        _burn(msg.sender, _share);
        // 将what数额的sushiToken发送到调用者账户
        sushi.transfer(msg.sender, what);
    }
}