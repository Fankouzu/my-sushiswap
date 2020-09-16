# SushiMaker合约
- 这个合约的主要目的是可以让用户将任意两个token的交易对的lpToken交给SushiMaker合约,然后SushiMaker合约会将两个token全部转换为SushiToken并发送到SushiBar合约
- 合约地址: https://etherscan.io/address/0x54844afe358Ca98E4D09AAe869f25bfe072E1B1a

- 交易hash https://etherscan.io/tx/0xd0d44d714ca19a5b1bc37308761f6763472c21f13270a18b3168705f637bbc33
## 构造函数

- 构造函数中设置了以下变量:
    - _factory 工厂合约地址
    - _bar Sushi Bar地址
    - _sushi Sushi Token地址
    - _weth WETH地址
- 对应的值如下
    - _factory: '0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac'
    - _bar: '0x8798249c2e607446efb7ad49ec89dd1865ff4272'
    - _sushi: '0x6b3595068778dd592e39a122f4f5a5cf09c90fe2'
    - _weth: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'

## 状态变量
- factory() 工厂合约地址
- bar() Sushi Bar地址
- sushi() Sushi Token地址
- weth() WETH地址

## 合约方法

### convert 转换方法
- 在调用转换方法之前需要将token0,token1对应的配对合约中的lpToken发送到当前SuShiMaker合约账户中
```
参数
address token0 //token0
address token0 //token1
```
1. 确认合约调用者为初始调用用户,防止通过合约调用此方法
2. 通过token0和token1找到配对合约地址,并实例化配对合约
3. 调用配对合约的transfer方法,将当前合约的lpToken余额发送到配对合约地址上
4. 调用配对合约的销毁方法,将流动性token销毁,之后配对合约将会向当前合约地址发送token0和token1
5. 将token0和token1全部交换为WETH并发送到WETH和SushiToken的配对合约上
6. 将WETH全部交换为Sushi Token并发送到Sushi 1Bar合约上

### _toWETH 将token卖出转换为WETH
- 将任意一种token转换为WETH
- 如果token是WETH则直接返回数额
- 如果token是SushiToken则返回0
```
参数
address token //token
```
1. 如果token地址是Sushi Token地址
    - 向SushiBar合约发送当前合约地址在token地址上的余额
    - 返回0(终止运行)
2. 如果token地址是WETH地址
    - 将当前合约地址在token地址上的余额,从当前合约发送到WETH和SushiToken的配对合约地址上(等待后面的购买操作)
    - 返回当前合约地址在token地址上的余额(终止运行)
3. 实例化token地址和WETH地址的配对合约
4. 如果配对合约地址为0地址,返回0(终止运行)
5. 从配对合约获取储备量0,储备量1
6. 找到token0(根据地址排序)
7. 排序形成储备量In和储备量Out
8. 定义输入数额为当前合约地址在token地址的余额
9. 税后输入数额为输入数额 * 997
10. 分子为税后输入数额 * 储备量Out
11. 分母为储备量In * 1000 + 税后输入数额
12. 输出数额为分子 / 分母
13. 排序输出数额0和输出数额1,有一个是0
14. 将输入数额发送到配对合约
15. 执行配对合约的交换方法(输出数额0,输出数额1,发送到WETH和token的配对合约上),相当于用卖出token换取WETH
16. 返回输出数额(WETH数额)

### _toSUSHI 将WETH交换为SushiToken
- 这个方法将WETH交换为SushiToken并发送到SushiBar合约
```
参数
uint256 amountIn //输入数额
```
1. 获取SushiToken和WETH的配对合约地址,并实例化配对合约
2. 获取配对合约的储备量0,储备量1
3. 找到token0
4. 排序生成储备量In和储备量Out
5. 税后输入数额为输入数额 * 997
6. 分子为税后输入数额 * 储备量Out
7. 分母为储备量In * 1000 + 税后输入数额
8. 输出数额为分子 / 分母
9. 排序输出数额0和输出数额1,有一个是0
10. 执行配对合约的交换方法(输出数额0,输出数额1,发送到sushiBar合约上)
