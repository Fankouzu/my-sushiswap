# SushiSwap 🍣 中文注释,中文文档

- via 崔棉大师

https://app.sushiswap.org. Feel free to read the code. More details coming soon.

## 中文文档

- [主厨合约](./MasterChef.md)

## Deployed Contracts / Hash

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

## 新feeToSetter操作
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