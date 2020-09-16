pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./SushiToken.sol";

//主厨合约地址 0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd

// 迁移合约接口
interface IMigratorChef {
    // 执行从旧版UniswapV2到SushiSwap的LP令牌迁移
    // Perform LP token migration from legacy UniswapV2 to SushiSwap.
    // 获取当前的LP令牌地址并返回新的LP令牌地址
    // Take the current LP token address and return the new LP token address.
    // 迁移者应该对调用者的LP令牌具有完全访问权限
    // Migrator should have full access to the caller's LP token.
    // 返回新的LP令牌地址
    // Return the new LP token address.
    //
    // XXX Migrator必须具有对UniswapV2 LP令牌的权限访问权限
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    //
    // SushiSwap必须铸造完全相同数量的SushiSwap LP令牌，否则会发生不良情况。
    // 传统的UniswapV2不会这样做，所以要小心！
    // SushiSwap must mint EXACTLY the same amount of SushiSwap LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// MasterChef是Sushi的主人。他可以做寿司，而且他是个好人。
//
// 请注意，它是可拥有的，所有者拥有巨大的权力。
// 一旦SUSHI得到充分分配，所有权将被转移到治理智能合约中，
// 并且社区可以展示出自我治理的能力
//
// 祝您阅读愉快。希望它没有错误。上帝保佑。

// MasterChef is the master of Sushi. He can make Sushi and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once SUSHI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // 用户信息
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.用户提供了多少个LP令牌。
        uint256 rewardDebt; // Reward debt. See explanation below.已奖励数额。请参阅下面的说明。
        //
        // 我们在这里做一些有趣的数学运算。基本上，在任何时间点，授予用户但待分配的SUSHI数量为：
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   待处理的奖励 =（user.amount * pool.accSushiPerShare）-user.rewardDebt
        //   pending reward = (user.amount * pool.accSushiPerShare) - user.rewardDebt
        //
        // 每当用户将lpToken存入到池子中或提取时。这是发生了什么：
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. 池子的每股累积SUSHI(accSushiPerShare)和分配发生的最后一个块号(lastRewardBlock)被更新
        //   1. The pool's `accSushiPerShare` (and `lastRewardBlock`) gets updated.
        //   2. 用户收到待处理奖励。
        //   2. User receives the pending reward sent to his/her address.
        //   3. 用户的“amount”数额被更新
        //   3. User's `amount` gets updated.
        //   4. 用户的`rewardDebt`已奖励数额得到更新
        //   4. User's `rewardDebt` gets updated.
    }

    // 池子信息
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.LP代币合约的地址
        uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.分配给该池的分配点数。 SUSHI按块分配
        uint256 lastRewardBlock; // Last block number that SUSHIs distribution occurs.SUSHIs分配发生的最后一个块号
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.每股累积SUSHI乘以1e12。见下文
    }

    // The SUSHI TOKEN!
    SushiToken public sushi;
    // Dev address.开发人员地址
    address public devaddr;
    // 奖励结束块号
    // Block number when bonus SUSHI period ends.
    uint256 public bonusEndBlock;
    // 每块创建的SUSHI令牌
    // SUSHI tokens created per block.
    uint256 public sushiPerBlock;
    // 早期寿司的奖金乘数
    // Bonus muliplier for early sushi makers.
    uint256 public constant BONUS_MULTIPLIER = 10;
    // 迁移者合同。它具有很大的力量。只能通过治理（所有者）进行设置
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // 池子信息数组
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // 池子ID=>用户地址=>用户信息 的映射
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // 总分配点。必须是所有池中所有分配点的总和
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // SUSHI挖掘开始时的块号
    // The block number when SUSHI mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    ); //紧急情况

    /**
     * @dev 构造函数
     * @param _sushi 寿司币地址
     * @param _devaddr 开发人员地址
     * @param _sushiPerBlock 每块创建的SUSHI令牌
     * @param _startBlock SUSHI挖掘开始时的块号
     * @param _bonusEndBlock 奖励结束块号
     */
    // 以下是sushiswap主厨合约布署时的参数
    // _sushi: '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2',
    // _devaddr: '0xF942Dba4159CB61F8AD88ca4A83f5204e8F4A6bd',
    // _sushiPerBlock: '100000000000000000000',
    // _startBlock: '10750000',
    // _bonusEndBlock: '10850000'
    constructor(
        SushiToken _sushi,
        address _devaddr,
        uint256 _sushiPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        sushi = _sushi;
        devaddr = _devaddr;
        sushiPerBlock = _sushiPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    /**
     * @dev 返回池子数量
     */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @dev 将新的lp添加到池中,只能由所有者调用
     * @param _allocPoint 分配给该池的分配点数。 SUSHI按块分配
     * @param _lpToken LP代币合约的地址
     * @param _withUpdate 触发更新所有池的奖励变量。注意gas消耗！
     */
    // Add a new lp to the pool. Can only be called by the owner.
    // XXX请勿多次添加同一LP令牌。如果您这样做，奖励将被搞砸
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        // 触发更新所有池的奖励变量
        if (_withUpdate) {
            massUpdatePools();
        }
        // 分配发生的最后一个块号 = 当前块号 > SUSHI挖掘开始时的块号 > 当前块号 : SUSHI挖掘开始时的块号
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        // 总分配点添加分配给该池的分配点数
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        // 池子信息推入池子数组
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accSushiPerShare: 0
            })
        );
    }

    /**
     * @dev 更新给定池的SUSHI分配点。只能由所有者调用
     * @param _pid 池子ID,池子数组中的索引
     * @param _allocPoint 新的分配给该池的分配点数。 SUSHI按块分配
     * @param _withUpdate 触发更新所有池的奖励变量。注意gas消耗！
     */
    // Update the given pool's SUSHI allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        // 触发更新所有池的奖励变量
        if (_withUpdate) {
            massUpdatePools();
        }
        // 总分配点 = 总分配点 - 池子数组[池子id].分配点数 + 新的分配给该池的分配点数
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        // 池子数组[池子id].分配点数 = 新的分配给该池的分配点数
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    /**
     * @dev 设置迁移合约地址,只能由所有者调用
     * @param _migrator 合约地址
     */
    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    /**
     * @dev 将lp令牌迁移到另一个lp合约。可以被任何人呼叫。我们相信迁移合约是正确的
     * @param _pid 池子id,池子数组中的索引
     */
    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        // 确认迁移合约已经设置
        require(address(migrator) != address(0), "migrate: no migrator");
        // 实例化池子信息构造体
        PoolInfo storage pool = poolInfo[_pid];
        // 实例化LP token
        IERC20 lpToken = pool.lpToken;
        // 查询LP token的余额
        uint256 bal = lpToken.balanceOf(address(this));
        // LP token 批准迁移合约控制余额数量
        lpToken.safeApprove(address(migrator), bal);
        // 新LP token地址 = 执行迁移合约的迁移方法
        IERC20 newLpToken = migrator.migrate(lpToken);
        // 确认余额 = 新LP token中的余额
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        // 修改池子信息中的LP token地址为新LP token地址
        pool.lpToken = newLpToken;
    }

    /**
     * @dev 给出from和to的块号,返回奖励乘积
     * @param _from from块号
     * @param _to to块号
     * @return 奖励乘积
     */
    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        // 如果to块号 <= 奖励结束块号
        if (_to <= bonusEndBlock) {
            // 返回 (to块号 - from块号) * 奖金乘数
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
            // 否则如果 from块号 >= 奖励结束块号
        } else if (_from >= bonusEndBlock) {
            // 返回to块号 - from块号
            return _to.sub(_from);
            // 否则
        } else {
            // 返回 (奖励结束块号 - from块号) * 奖金乘数 + (to块号 - 奖励结束块号)
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    /**
     * @dev 查看功能以查看用户的处理中尚未领取的SUSHI
     * @param _pid 池子id
     * @param _user 用户地址
     * @return 处理中尚未领取的SUSHI数额
     */
    // View function to see pending SUSHIs on frontend.
    function pendingSushi(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        // 实例化池子信息
        PoolInfo storage pool = poolInfo[_pid];
        // 根据池子id和用户地址,实例化用户信息
        UserInfo storage user = userInfo[_pid][_user];
        // 每股累积SUSHI
        uint256 accSushiPerShare = pool.accSushiPerShare;
        // LPtoken的供应量 = 当前合约在`池子信息.lpToken地址`的余额
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        // 如果当前区块号 > 池子信息.分配发生的最后一个块号 && LPtoken的供应量 != 0
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            // 奖金乘积 = 获取奖金乘积(分配发生的最后一个块号, 当前块号)
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            // sushi奖励 = 奖金乘积 * 每块创建的SUSHI令牌 * 池子分配点数 / 总分配点数
            uint256 sushiReward = multiplier
                .mul(sushiPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            // 每股累积SUSHI = 每股累积SUSHI + sushi奖励 * 1e12 / LPtoken的供应量
            accSushiPerShare = accSushiPerShare.add(
                sushiReward.mul(1e12).div(lpSupply)
            );
        }
        // 返回 用户.已添加的数额 * 每股累积SUSHI / 1e12 - 用户.已奖励数额
        return user.amount.mul(accSushiPerShare).div(1e12).sub(user.rewardDebt);
    }

    /**
     * @dev 更新所有池的奖励变量。注意汽油消耗
     */
    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        // 池子数量
        uint256 length = poolInfo.length;
        // 遍历所有池子
        for (uint256 pid = 0; pid < length; ++pid) {
            // 升级池子(池子id)
            updatePool(pid);
        }
    }

    /**
     * @dev 将给定池的奖励变量更新为最新
     * @param _pid 池子id
     */
    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        // 实例化池子信息
        PoolInfo storage pool = poolInfo[_pid];
        // 如果当前区块号 <= 池子信息.分配发生的最后一个块号
        if (block.number <= pool.lastRewardBlock) {
            // 直接返回
            return;
        }
        // LPtoken的供应量 = 当前合约在`池子信息.lotoken地址`的余额
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        // 如果 LPtoken的供应量 == 0
        if (lpSupply == 0) {
            // 池子信息.分配发生的最后一个块号 = 当前块号
            pool.lastRewardBlock = block.number;
            // 返回
            return;
        }
        // 奖金乘积 = 获取奖金乘积(分配发生的最后一个块号, 当前块号)
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        // sushi奖励 = 奖金乘积 * 每块创建的SUSHI令牌 * 池子分配点数 / 总分配点数
        uint256 sushiReward = multiplier
            .mul(sushiPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        // 调用sushi的铸造方法, 为管理团队铸造 (`sushi奖励` / 10) token
        sushi.mint(devaddr, sushiReward.div(10));
        // 调用sushi的铸造方法, 为当前合约铸造 `sushi奖励` token
        sushi.mint(address(this), sushiReward);
        // 每股累积SUSHI = 每股累积SUSHI + sushi奖励 * 1e12 / LPtoken的供应量
        pool.accSushiPerShare = pool.accSushiPerShare.add(
            sushiReward.mul(1e12).div(lpSupply)
        );
        // 池子信息.分配发生的最后一个块号 = 当前块号
        pool.lastRewardBlock = block.number;
    }

    /**
     * @dev 将LP令牌存入MasterChef进行SUSHI分配
     * @param _pid 池子id
     * @param _amount 数额
     */
    // Deposit LP tokens to MasterChef for SUSHI allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        // 实例化池子信息
        PoolInfo storage pool = poolInfo[_pid];
        // 根据池子id和当前用户地址,实例化用户信息
        UserInfo storage user = userInfo[_pid][msg.sender];
        // 将给定池的奖励变量更新为最新
        updatePool(_pid);
        // 如果用户已添加的数额>0
        if (user.amount > 0) {
            // 待定数额 = 用户.已添加的数额 * 池子.每股累积SUSHI / 1e12 - 用户.已奖励数额
            uint256 pending = user
                .amount
                .mul(pool.accSushiPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            // 向当前用户安全发送待定数额的sushi
            safeSushiTransfer(msg.sender, pending);
        }
        // 调用池子.lptoken的安全发送方法,将_amount数额的lp token从当前用户发送到当前合约
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        // 用户.已添加的数额  = 用户.已添加的数额 + _amount数额
        user.amount = user.amount.add(_amount);
        // 用户.已奖励数额 = 用户.已添加的数额 * 池子.每股累积SUSHI / 1e12
        user.rewardDebt = user.amount.mul(pool.accSushiPerShare).div(1e12);
        // 触发存款事件
        emit Deposit(msg.sender, _pid, _amount);
    }

    /**
     * @dev 从MasterChef提取LP令牌
     * @param _pid 池子id
     * @param _amount 数额
     */
    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        // 实例化池子信息
        PoolInfo storage pool = poolInfo[_pid];
        // 根据池子id和当前用户地址,实例化用户信息
        UserInfo storage user = userInfo[_pid][msg.sender];
        // 确认用户.已添加数额 >= _amount数额
        require(user.amount >= _amount, "withdraw: not good");
        // 将给定池的奖励变量更新为最新
        updatePool(_pid);
        // 待定数额 = 用户.已添加的数额 * 池子.每股累积SUSHI / 1e12 - 用户.已奖励数额
        uint256 pending = user.amount.mul(pool.accSushiPerShare).div(1e12).sub(
            user.rewardDebt
        );
        // 向当前用户安全发送待定数额的sushi
        safeSushiTransfer(msg.sender, pending);
        // 用户.已添加的数额  = 用户.已添加的数额 - _amount数额
        user.amount = user.amount.sub(_amount);
        // 用户.已奖励数额 = 用户.已添加的数额 * 池子.每股累积SUSHI / 1e12
        user.rewardDebt = user.amount.mul(pool.accSushiPerShare).div(1e12);
        // 调用池子.lptoken的安全发送方法,将_amount数额的lp token从当前合约发送到当前用户
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        // 触发提款事件
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /**
     * @dev 提款而不关心奖励。仅紧急情况
     * @param _pid 池子id
     */
    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        // 实例化池子信息
        PoolInfo storage pool = poolInfo[_pid];
        // 根据池子id和当前用户地址,实例化用户信息
        UserInfo storage user = userInfo[_pid][msg.sender];
        // 调用池子.lptoken的安全发送方法,将_amount数额的lp token从当前合约发送到当前用户
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        // 触发紧急提款事件
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        // 用户.已添加数额 = 0
        user.amount = 0;
        // 用户.已奖励数额 = 0
        user.rewardDebt = 0;
    }

    /**
     * @dev 安全的寿司转移功能，以防万一舍入错误导致池中没有足够的寿司
     * @param _to to地址
     * @param _amount 数额
     */
    // Safe sushi transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeSushiTransfer(address _to, uint256 _amount) internal {
        // sushi余额 = 当前合约在sushi的余额
        uint256 sushiBal = sushi.balanceOf(address(this));
        // 如果数额 > sushi余额
        if (_amount > sushiBal) {
            // 按照sushi余额发送sushi到to地址
            sushi.transfer(_to, sushiBal);
        } else {
            // 按照_amount数额发送sushi到to地址
            sushi.transfer(_to, _amount);
        }
    }

    /**
     * @dev 通过先前的开发者地址更新开发者地址
     * @param _devaddr 开发者地址
     */
    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        // 确认当前账户是开发者地址
        require(msg.sender == devaddr, "dev: wut?");
        // 赋值新地址
        devaddr = _devaddr;
    }
}
