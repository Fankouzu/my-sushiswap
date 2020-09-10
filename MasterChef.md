# 主厨合约

- 合约地址: https://etherscan.io/address/0xc2edad668740f1aa35e4d8f227fb8e17dca888cd

- 交易hash https://etherscan.io/tx/0x3d68b0d8a94838af33070b8f00558e723f073b23772bd1760f1f4032e21e0fb3
## 构造函数

- 构造函数中设置了以下变量:
    - Sushi Token的地址
    - 开发者帐号地址
    - 每个区块创建Sushi Token的数量
    - Sushi Token开始挖掘的区块号
    - 奖励结束的区块号
- 对应的值如下
    - _sushi: '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2'
    - _devaddr: '0xF942Dba4159CB61F8AD88ca4A83f5204e8F4A6bd'
    - _sushiPerBlock: '100000000000000000000'
    - _startBlock: '10750000'
    - _bonusEndBlock: '10850000'

## 状态变量,只读方法
- sushi() Sushi Token的地址
- devaddr() 开发者帐号地址
- sushiPerBlock() 每个区块创建Sushi Token的数量
- BONUS_MULTIPLIER() Sushi Token的奖金乘数
- migrator() 迁移合约地址
- poolInfo(uint256 池子id) 池子信息
- userInfo(uint256 池子id,address 用户地址) 用户信息
- totalAllocPoint() 总分配点,所有池中所有分配点的总和
- startBlock() Sushi Token开始挖掘的区块号
- poolLength() 返回池子数量
- getMultiplier(uint256 from块号,uint256 to块号) 给出from和to的块号,返回奖励乘数
- pendingSushi(uint256 池子id, address 用户地址) 查看功能以查看用户的处理中尚未领取的SUSHI

## 池子信息(重要)
```
struct PoolInfo {
    IERC20 lpToken; // LP代币(配对合约)的地址
    uint256 allocPoint; // 分配给该池的分配点数。 SUSHI按块分配
    uint256 lastRewardBlock; // SUSHIs分配发生的最后一个块号
    uint256 accSushiPerShare; // 每股累积SUSHI乘以1e12
}
```

## 用户信息(重要)
```
struct UserInfo {
    uint256 amount; // 用户提供了多少个lpToken。
    uint256 rewardDebt; // 已奖励数额。请参阅下面的说明。
}
// 我们在这里做一些有趣的数学运算。基本上，在任何时间点，授予用户但待分配的SUSHI数量为：
//   待处理的奖励 =（用户添加的lpToken * 每股累积SUSHI）- 已奖励数额
//
// 每当用户将lpToken存入到池子中或提取时。这是发生了什么：
//   1. 池子的每股累积SUSHI(accSushiPerShare)和分配发生的最后一个块号(lastRewardBlock)被更新
//   2. 用户收到待处理奖励。
//   3. 用户的“amount”数额被更新
//   4. 用户的`rewardDebt`已奖励数额得到更新
```
## 合约方法

### 名词示意
- lpToken: Uniswap中每一个交易对都有一个配对合约,当你将两个Token存入到Uniswap交易所之后,Uniswap交易所会为你找到这个配对合约,并将你的两个Token存入到合约中,然后配对合约其实也是一个ERC20标准的Token合约,所以这个配对合约为了记录你存入的数额,就会为你生成配对合约的ERC20 Token,我们将这个Token称为lpToken,lp的意思是"流动性".在配对合约中lpToken的数额计算方法为:(tokenA数额*tokenB数额)的平方根.因为lpToken是标准的ERC20 token,所以就可以转让给另一个账户.在sushiSwap中存入的就是这个lpToken,当你将lpToken存入到sushiSwap之后,sushiSwap就有权利使用你的lpToken将Uniswap交易所的配对合约中的你存入的两个Token全部取出.

### add 将新的流动性Token添加到池中
- 这个方法只能由所有者调用

- 所有者通过这个方法将新的uniswap交易对的流动性token配对合约地址添加到池中,创建新的流动性挖矿池子
```
参数
uint256 _allocPoint //分配给该池的分配点数。 SUSHI按块分配
IERC20 _lpToken //lpToken合约的地址
bool _withUpdate //触发更新所有池的奖励变量。注意gas消耗！
```
1. 如果_withUpdate的值为真,则触发更新所有池子奖励的方法
2. 定义分配发生的最后一个块号
    - 新池子的分配发送最后块号应该是当期区块号
    - 如果当前区块号没到开始挖矿的区块号,则取开始挖矿的区块号
3. 将参数中的分配点数入到总分配点
4. 将池子信息定义到构造体中,并推入池子数组

### set 更新给定池的SUSHI分配点
- 这个方法只能由所有者调用

- 通过这个方法调整现有池子的SUSHI分配点
```
参数
uint256 _pid //池子ID,池子数组中的索引
uint256 _allocPoint //新的分配给该池的分配点数。 SUSHI按块分配
bool _withUpdate //触发更新所有池的奖励变量。注意gas消耗！
```
1. 如果_withUpdate的值为真,则触发更新所有池子奖励的方法
2. 根据参数的新分配点数,将总分配点数调整正确,方法是将总分配点数减去给定池子的旧分配点数,再加上新分配点数,这样不管新分配点数比旧分配点数大还是小都能确保调整正确
3. 调整池子信息映射中的池子构造体中的分配点数

### setMigrator 设置迁移合约地址
- 这个方法比较简单,只负责将migrator变量设置成新的值
```
参数
IMigratorChef _migrator //合约地址
```

### migrate 迁移方法
- 将lp令牌迁移到另一个lp合约。可以被任何人呼叫。我们相信迁移合约是正确的

- 这个方法用作将主厨合约持有的指定池子中的lp Token(uniswap的配对合约)批准给迁移合约,然后调用迁移合约的迁移方法,迁移的工作过程请看迁移合约的文档
```
参数
uint256 _pid //池子id,池子数组中的索引
```
1. 确认迁移合约地址已经被设置
2. 查询到主厨合约在给定池子的lpToken的余额
3. 调用迁移合约,并执行迁移方法,返回新的SushiSwap的lpToken地址
4. 查询并确认新lpToken合约中当前主厨合约地址的余额,与旧的uniswap合约余额相等

### getMultiplier 给出from和to的块号,返回奖励乘积
- 奖励乘数是指在奖励区块内,奖励的倍数,当一个用户要取出奖励的时候,他有可能有一部分未取出金额在奖励区块范围内,一部分不在,或者都在,或者都不在,所以要通过这个方法计算出一个乘积
```
参数
uint256 _from //from块号
uint256 _to //to块号
```
1. 如果to块号小于奖励结束的块号,说明整个区间都在奖励范围内,则返回from-to的块数乘以固定奖励乘数(10倍)
2. 如果from大于奖励结束的块号,说明整个区间都在奖励范围之外,则返回from-to的块数
3. 其他情况说明一部分在奖励区块内,一部分不在,所以先取得奖励区块内的范围(奖励结束块号-from块号)再乘以奖励乘数(10倍),然后再加上奖励区块外的块数(to块号-奖励结束块号),然后就可以获得正确的奖励乘积
4. 返回乘积

### pendingSushi 查看功能以查看用户的处理中尚未领取的SUSHI
- 领取sushiToken需要写入操作触发,所以在没有写入操作触发之前,用户的sushiToken处于pending状态,这个方法可以计算出用户处在pending状态的sushiToken

- 计算方法的本质是通过池子上次最后奖励的区块到当前区块的数量计算出整个池子应得的sushi数量,然后再计算出池子中每股累计sushi奖励数值,最后使用用户存入的lpToken数值乘以每股奖励数值,再减去用户已领取的奖励数值计算出尚未领取的sushi数值
```
参数
uint256 _pid //池子id
address _user //用户地址
```
1. 实例化池子信息,实例化用户信息
2. 取出每股累计Sushi,每一个lpToken累计获得过多少Sushi
2. 计算当前主厨合约在给定的池子(uniswap配对合约)中的lpToken余额
3. 先判断当前区块是否大于池子的最后奖励区块
    - 计算出奖金乘积,通过池子最后奖励区块作为from,当前区块作为to得到奖金乘积
    - 计算sushi奖励,用奖金乘积,乘以sushi每块奖励,乘以池子的分配点数,除以所有池子总点数(取得池子站全部sushiToken分配的占比)
    - 计算每股累计sushi,使用sushi的奖励除以lpToken的余额累计获得
4. 返回,尚未领取的sushi数额等于:用户已添加到池子中的lpToken数额,乘以每股累计奖励Sushi的数额,减去用户已领取的奖励数额

### massUpdatePools 更新所有池的奖励变量
- 这个方法比较简单,通过池子数组的长度遍历池子数组,然后执行升级池子的方法
1. 取出池子数组长度
2. 循环遍历池子数组
    - 根据池子id升级池子数组

### updatePool 将给定池的奖励变量更新为最新
- 这个方法的本质是通过上次最后奖励的区块到当前的区块数量计算出池子应得的sushi奖励数额,然后再计算出池子中每股累计sushi奖励数值,池子信息中只记录每股累计奖励数值,不记录sushi奖励数值
```
参数
uint256 _pid //池子id
```
1. 实例化池子信息
2. 如果当前区块小于给定池子的分配发生的最后一个区块,则返回(终止运行,为了防止意外发生)
3. 计算当前主厨合约在给定的池子(uniswap配对合约)中的lpToken余额
4. 如果lpToken余额为0,更新池子信息中分配发生的最后一个区块号为当前区块号,然后返回(终止运行)
5. 计算出奖金乘积,通过池子最后奖励区块作为from,当前区块作为to得到奖金乘积
6. 计算sushi奖励,用奖金乘积,乘以sushi每块奖励,乘以池子的分配点数,除以所有池子总点数(取得池子站全部sushiToken分配的占比)
7. 为开发者账号铸造sushiToken,数量为sushi奖励除以10(10为固定值不可更改)
8. 为当前主厨合约铸造sushiToken,数量为sushi奖励数额
9. 计算每股累计sushi,使用sushi的奖励除以lpToken的余额累计获得
10. 更新池子信息中的分配发生的最后一个区块

### deposit 用户将lpToken存入主厨合约并进行SUSHI分配
- 用户通过这个方法将Uniswap的Lptoken存入到主厨合约

- 如果当前用户之前存入过lpToken则将之前应获得的sushi奖励发送到用户账户中
```
参数
uint256 _pid //池子id
uint256 _amount //数额
```
1. 实例化池子信息,实例化用户信息
2. 取出每股累计Sushi,每一个lpToken累计获得过多少Sushi
3. 通过updatePool方法,将给定池的奖励变量更新为最新
4. 如果用户已添加的数额>0
    - 计算用户处理中的sushi奖励数额(通过用户存入的lpToken数额*池子的每股累计奖励sushi-用户已领取的sushi数额)
    - 向调用者发送sushiToken,数额为处理中的奖励数额
5. 调用lpToken的安全发送方法,从调用者账户发送数额为_amount的lpToken到当前合约地址(调用方法前需要用户appove批准lpToken给主厨合约大于等于_amount的数额)
6. 累加用户已添加的数额
7. 计算用户已领取sushi的奖励数额,通过用户已添加的数额乘以池子中的每股奖励sushi数额(如果用户第一次添加,也将会有已奖励数额,目的为了排除第一次添加之前的数额)

### withdraw 用户从主厨合约提取lpToken
- 用户通过这个方法将主厨合约中的unswap都lpToken取出到自己的账户中

- 如果用户有处理中的sushi奖励,则发送给用户账户
```
参数
uint256 _pid //池子id
uint256 _amount //数额
```
1. 实例化池子信息,实例化用户信息
2. 确认用户已添加的数额大于等于将要取出的数额
3. 通过updatePool方法,将给定池的奖励变量更新为最新
4. 计算用户处理中的sushi奖励数额(通过用户存入的lpToken数额*池子的每股累计奖励sushi-用户已领取的sushi数额)
5. 向调用者发送sushiToken,数额为处理中的奖励数额
6. 用户已添加的数额减去将要取出的数额
7. 计算用户已领取sushi的奖励数额,通过用户取出后剩余的数额乘以池子中的每股奖励sushi数额
8. 调用lpToken的安全发送方法,从当前合约地址发送数额为_amount的lpToken到调用者账户

### emergencyWithdraw 紧急提取方法,仅限紧急情况
- 调用这个方法将会把用户存在当前主厨合约的lpToken数额提取到自己的账户中,如果用户存在处理中的sushi奖励将会被忽略
```
参数
uint256 _pid //池子id
```
1. 实例化池子信息,实例化用户信息
2. 调用lpToken的安全发送方法,从当前合约地址发送数额为调用者账户全部存入数额的lpToken到调用者账户
3. 触发紧急提款事件
4. 为用户的存入数额和已领取sushi奖励的数额都归零

### safeSushiTransfer 安全的sushi转移功能
- 这个方法是为了防止要发送的sushi Token数额大于当前合约在sushi Token的余额而设计的
```
参数
address _to //to地址
uint256 _amount //数额
```
1. 计算当前主厨合约在sushi TOken的余额
2. 判断如果_amount要发送的数额大于当前合约的余额
    - 调用sushi TOken的发送方法,从当前合约向_to地址发送数量为当前合约全部余额的sushi
3. 否则
    - 调用sushi TOken的发送方法,从当前合约向_to地址发送数量_amount的sushi

### dev 更新开发者账号
- 通过先前的开发者地址更新开发者地址
```
参数
address _devaddr //开发者地址
```
1. 确认调用者为当前_devaddr地址
2. 修改devaddr为参数中的_devaddr地址

