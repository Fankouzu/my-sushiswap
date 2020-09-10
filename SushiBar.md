# SushiBar合约
- SushiBar是一个接收用户转账SushiToken然后转换为xSUSHI的合约,xSUSHI的数额相当于你在SushiBar的份额,可以随时进入和退出
- 进入之后你的xSUSHI为存入的SushiToken*(xSUSHI总发行量/合约的SushiToken余额)
- 合约地址: https://etherscan.io/address/0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272

- 交易hash https://etherscan.io/tx/0x7fdb7a46473bcb6748c597f5f299ff76fe059294a6e4f8e9bdb0b5fe643ff92e
## 构造函数

- 构造函数中设置了以下变量:
    - Sushi Token地址
- 对应的值如下
    - _sushi: '0x6b3595068778dd592e39a122f4f5a5cf09c90fe2'

## 状态变量
- sushi() Sushi Token地址

## ERC20标准方法略

## 合约方法

### enter 进入吧台
- 将自己的sushiToken发送到合约换取份额
```
参数
uint256 _amount //SushiToken数额
```
1. 计算当前SushiBar合约的SushiToken余额
2. 计算当前SushiBar合约的总发行量
3. 如果SushiToken余额或者SushiBar合约的总发行量有一个为0
    - 为调用者账户铸造数量为_amount的xSUSHI
4. 否则
    - 按照xSUSHI总发行量/合约的SushiToken余额的比例关系将存入数额_amount计算成`份额`
    - 为调用者账户铸造数量为`份额`的xSUSHI
5. 将调用者的SushiToken发送到当前合约

### leave 离开吧台
- 取回自己的sushiToken
```
参数
uint256 _share //SUSHIs数额
```
1. 计算当前SushiBar合约的总发行量
2. 按照合约的SushiToken余额/xSUSHI总发行量的比例关系将SUSHIs数额计算成SushiToken数额
3. 为调用者销毁SUSHIs数额
5. 将当前合约的SushiToken发送到调用者账户

