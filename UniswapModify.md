# Uniswap 合约修改文档
- 为了配合SushiSwap的运行,Uniswap做了一些修改

## 工厂合约
- 增加迁移合约地址
```
// 迁移合约地址
address public override migrator;
```
- 增加配对合约Bytecode的Hash值读取方法(原来的Uniswp没有这个方法,导致布署路由合约经常错误)
```
// 配对合约源代码Bytecode的hash值(用作前端计算配对合约地址)
function pairCodeHash() external pure returns (bytes32) {
    return keccak256(type(UniswapV2Pair).creationCode);
}
```
- 增加设置迁移合约地址的方法(迁移合约地址初始值为0地址)
```
// 设置迁移合约地址的方法,只能由feeToSetter设置
function setMigrator(address _migrator) external override {
    require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
    migrator = _migrator;
}
```

# 配对合约
- 在铸造方法中增加一个判断调用铸造方法的账户是否属于迁移合约的逻辑
```
function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20Uniswap(token0).balanceOf(address(this));
        uint balance1 = IERC20Uniswap(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            // 定义迁移合约,从工厂合约中调用迁移合约的地址
            address migrator = IUniswapV2Factory(factory).migrator();
            // 如果调用者是迁移合约(说明是正在执行迁移操作)
            if (msg.sender == migrator) {
                // 流动性 = 迁移合约中的`需求流动性数额`,这个数额在交易开始之前是无限大,交易过程中调整为lpToken迁移到数额,交易结束之后又会被调整回无限大
                liquidity = IMigrator(migrator).desiredLiquidity();
                // 确认流动性数额大于0并且不等于无限大
                require(liquidity > 0 && liquidity != uint256(-1), "Bad desired liquidity");
                // 否则
            } else {
                // 确认迁移地址等于0地址(说明不在迁移过程中,属于交易所营业后的创建流动性操作)
                require(migrator == address(0), "Must not have migrator");
                liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
                _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
            }
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }
```