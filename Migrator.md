# 迁移合约

- 合约地址: https://etherscan.io/address/0x93ac37f13bffcfe181f2ab359cc7f67d9ae5cdfd

- 交易hash https://etherscan.io/tx/0x2e93327b9a1b65c10ab20679a4b52cb657e3c617023afaefb5a04a1a0e261ac6
## 构造函数

- 构造函数中设置了以下变量:
    - 主厨合约地址
    - 旧工厂合约地址(Uniswap工厂合约)
    - 新工厂合约
    - 不能早于的块号
- 对应的值如下
    - _chef: '0xc2edad668740f1aa35e4d8f227fb8e17dca888cd'
    - _oldFactory: '0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f'
    - _factory: '0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac'
    - _notBeforeBlock: '0'

## 状态变量
- chef() 主厨合约地址
- oldFactory() Uniswap工厂合约地址
- factory() SushiSwap新工厂合约
- notBeforeBlock() 不能早于的块号
- desiredLiquidity() 需求流动性数额 = 无限大

## migrate 迁移方法
- 这个方法简要概括实现的是将主厨合约的lpToken发送给Uniswap配对合约,然后执行Uniswap配对合约的销毁方法
- Uniswap的销毁方法执行后,会将配对合约账户中的两个token返还给指定账户(这里就是SushiSwap新配对合约)
- 随后执行SushiSwap新配对合约的铸造方法,为主厨合约铸造SushiSwap新的lpToken
```
参数
IUniswapV2Pair orig //Uniswap配对合约地址
```
1. 确认当前用户是主厨合约地址,并且发起交易的地址为SBF的帐号地址(说明是SBF发起的交易,通过主厨合约调用的迁移合约)
2. 确认当前块号大于不能早于的块号
3. 确认配对合约的工厂合约地址等于旧工厂合约地址,通过调用旧配对合约的工厂合约变量查询到的
4. 从Uniswap配对合约中查询到token0和token1,两个token是按照16进制数字的大小排序的
5. 通过SushiSwap工厂合约的获取配对方法获取配对合约地址
6. 如果获取到的配对合约地址为0地址,说明配对合约不存在,则调用SushiSwap工厂合约的创建配对方法,创建token0和token1的配对合约
7. 确认配对合约的总量为0,说明之前没有执行过迁移
8. 获取当前用户(主厨合约)在Uniswap配对合约的lpToken余额
9. 如果流动性数量为0,直接返回配对合约地址(终止运行)
10. 定义需求流动性数额等于获取到的Uniswap配对合约流动性数量
11. 调用Uniswap配对合约的发送方法,从主厨合约将流动性数量发送到旧配对合约(在主厨合约中已主厨合约已将数额批准给了迁移合约)
12. 调用Uniswap配对合约的销毁方法,销毁方法会将token0,token1发送到SushiSwap的新配对合约
13. 调用SushiSwap新配对合约的铸造方法给主厨合约铸造新流动性token
14. 将需求的流动性数额调整回无限大
15. 返回SushiSwap新配对合约地址