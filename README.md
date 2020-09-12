# SushiSwap 🍣 中文注释,中文文档

- via 崔棉大师

https://app.sushiswap.org. Feel free to read the code. More details coming soon.

## 中文文档

- [MasterChef主厨合约文档](./MasterChef.md)
- [SushiToken文档](./SushiToken.md)
- [Migrator迁移合约文档](./Migrator.md)
- [SushiMaker文档](./SushiMaker.md)
- [SushiBar文档](./SushiBar.md)
- [Uniswap合约修改文档](./UniswapModify.md)

## 合约文件中文注释

- [MasterChef主厨合约](./Contracts/MasterChef.sol)
- [SushiToken合约](./Contracts/SushiToken.sol)
- [Migrator迁移合约](./Contracts/Migrator.sol)
- [SushiMaker合约](./Contracts/SushiMaker.sol)
- [SushiBar合约](./Contracts/SushiBar.sol)
- [Uniswap工厂合约](./ontracts/uniswapv2/UniswapV2Factory.sol)
- [Uniswap配对合约](./ontracts/uniswapv2/UniswapV2Pair.sol)

## SushiSwap合约布署顺序

1. 布署SushiToken,没有构造函数,SushiToken初始代币总量为0
2. 布署主厨合约,构造函数中需要SushiToken的地址和开发者账号地址,还需要定义开始区块等参数
3. 可以开始运行质押挖矿了,直到挖矿期结束,开始迁移工作
4. 布署Uniswap工厂合约,构造函数为收税地址管理员账号,这个账号可以设置税款接收地址,目前为SBF掌握
5. 布署Uniswap路由合约,构造函数为工厂合约地址和WETH地址
6. 布署迁移合约,构造函数中包括主厨合约地址,Uniswap工厂合约地址,SushiSwap工厂合约地址和执行迁移不能早于的区块号
7. 现在可以执行迁移操作了
8. 布署SushiBar合约,构造函数中为SushiToken的合约地址
9. 布署SushiMaker合约,构造函数中为SushiSwap工厂合约地址,SushiBar合约地址,SushiToken的合约地址,WETH合约地址,只有要把SushiSwap工厂合约的feeTo地址设置为SushiMaker的地址
10. 现在SushiSwap已经可以正常运行了,0.05%的手续费税款会转到SushiMaker的地址,通过调用SushiMaker的合约方法可以将手续费税款对应的资产一步操作全部购买成SushiToken,然后会将SushiToken转到SushiBar合约

## SushiSwap合约地址/Hash

- 主厨Nomi的地址 - https://etherscan.io/address/0xf942dba4159cb61f8ad88ca4a83f5204e8f4a6bd
- SushiToken - https://etherscan.io/token/0x6b3595068778dd592e39a122f4f5a5cf09c90fe2
- MasterChef - https://etherscan.io/address/0xc2edad668740f1aa35e4d8f227fb8e17dca888cd
- (Uni|Sushi)swapV2Factory - https://etherscan.io/address/0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac
- (Uni|Sushi)swapV2Router02 - https://etherscan.io/address/0xd9e1ce17f2641f24ae83637ab66a2cca9c378b9f
- (Uni|Sushi)swapV2Pair init code hash - `e18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303`
- SushiBar - https://etherscan.io/address/0x8798249c2e607446efb7ad49ec89dd1865ff4272
- SushiMaker - https://etherscan.io/address/0x54844afe358ca98e4d09aae869f25bfe072e1b1a
- MultiSigWalletWithDailyLimit - https://etherscan.io/address/0xf73b31c07e3f8ea8f7c59ac58ed1f878708c8a76
- Timelock - https://etherscan.io/address/0x9a8541ddf3a932a9a922b607e9cf7301f1d47bd1
- old migrator - https://etherscan.io/address/0x818180acb9d300ffc023be2300addb6879d94830
- migrator - https://etherscan.io/address/0x93ac37f13bffcfe181f2ab359cc7f67d9ae5cdfd

## 大厨操作
- setFeeToSetter - https://etherscan.io/tx/0x2032ce062801e5d9ba03d7717491df6eaba513e5ae536cb97726f58daa66cd92
> 将feeToSetter地址设置为 0xd57581d9e42e9032e6f60422fa619b4a4574ba79
- transferOwnership https://etherscan.io/tx/0x414204c5bd062c86812b9bf5bedadd96c370a743f095430a413c961105adc8ac
> nomi将主厨合约的owner身份转移到时间锁合约
- queueTransaction - https://etherscan.io/tx/0xf5d8251f7fbb8b8d64607e7538f644b3eb1cb11864d7490821df6e4f88bac1e3
> 在时间锁合约中提交setMigrator交易,交易将在48小时后执行
- setPendingAdmin - https://etherscan.io/tx/0x8e2f3f27e616d8be2d2d3095a996cf4c0af8c9c757c7ff034d352c11cc082394
> 将时间锁合约管理员设置为0xd57581d9e42e9032e6f60422fa619b4a4574ba79
- 抛售的交易 - https://etherscan.io/tx/0x419a835b33eb03481e56a5f964c1c31017ab196cb7bb4390228cabcf50dfd6f1

## SBF操作
- 地址 - https://etherscan.io/address/0xd57581d9e42e9032e6f60422fa619b4a4574ba79
- acceptAdmin - https://etherscan.io/tx/0x251508ad94261ed3de6eff3e86bf888a4b40ce49fdbe29189e6d48d7b6c6804b
> 接受时间锁合约的管理员
- cancelTransaction - https://etherscan.io/tx/0x1c95d23fad620274971323e09bbb425b17169927c13e2554a175aa9da974f4f9
> 取消时间锁合约的setMigrator交易
- setMigrator - https://etherscan.io/tx/0xafb807819d00fd1f4a6ba4ef17370acb4ef39f199e6930e462bcd75de63244d2
> 执行sushi工厂合约中的setMigrator方法,在工厂合约中设置迁移合约地址,此方法为将来运行交易所做准备,并不能执行迁移操作
- queueTransaction - https://etherscan.io/tx/0x416a19f54d85de00b5cfcb7f498e61e5867b2a88e981c8396ea3e27ab7388cac
> 重新提交setMigrator交易,将迁移合约地址设置为0x93ac37f13bffcfe181f2ab359cc7f67d9ae5cdfd

## License

WTFPL