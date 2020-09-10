pragma solidity 0.6.12;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 具有治理功能的SushiToken 地址 0x6b3595068778dd592e39a122f4f5a5cf09c90fe2
// SushiToken with Governance.
contract SushiToken is ERC20("SushiToken", "SUSHI"), Ownable {
    /// @notice 为_to创建`_amount`令牌。只能由所有者（MasterChef）调用
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        // ERC20的铸币方法
        _mint(_to, _amount);
        // 移动委托,将amount的数额的票数转移到to地址的委托人
        _moveDelegates(address(0), _delegates[_to], _amount);
    }

    // 从YAM的代码复制过来的
    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // 从COMPOUND代码复制过来的
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    // @notice 每个账户的委托人记录
    // @notice A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice 一个检查点，用于标记给定块中的投票数
    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice 按索引记录每个帐户的选票检查点 地址=>索引=>检查点构造体
    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;
    /// @notice 每个帐户的检查点数映射,地址=>数额
    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice EIP-712的合约域hash
    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice EIP-712的代理人构造体的hash
    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice 用于签名/验证签名的状态记录
    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice 帐户更改其委托时发出的事件
      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice 当代表帐户的投票余额更改时发出的事件
    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /**
     * @notice 查询delegator的委托人
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator 被委托的地址
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        // 返回委托人地址
        return _delegates[delegator];
    }

   /**
    * @notice 转移当然用户的委托人
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee 委托人地址
    */
    function delegate(address delegatee) external {
        // 将`msg.sender` 的委托人更换为 `delegatee`
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice 从签署人到delegatee的委托投票
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee 委托人地址
     * @param nonce nonce值,匹配签名所需的合同状态
     * @param expiry 签名到期的时间 
     * @param v 签名的恢复字节
     * @param r ECDSA签名对的一半 
     * @param s ECDSA签名对的一半 
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        // 域分割 = hash(域hash + 名字hash + chainId + 当前合约地址)
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        // 构造体hash = hash(构造体的hash + 委托人地址 + nonce值 + 过期时间)
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        // 签名前数据 = hash(域分割 + 构造体hash)
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        // 签署人地址 = 恢复地址方法(签名前数据,v,r,s) v,r,s就是签名,通过签名和签名前数据恢复出签名人的地址
        address signatory = ecrecover(digest, v, r, s);
        // 确认签署人地址 != 0地址
        require(signatory != address(0), "SUSHI::delegateBySig: invalid signature");
        // 确认 nonce值 == nonce值映射[签署人]++
        require(nonce == nonces[signatory]++, "SUSHI::delegateBySig: invalid nonce");
        // 确认 当前时间戳 <= 过期时间
        require(now <= expiry, "SUSHI::delegateBySig: signature expired");
        // 返回更换委托人
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice 获取`account`的当前剩余票数
     * @notice Gets the current votes balance for `account`
     * @param account 账户地址
     * @return 剩余票数
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        // 检查点数 = 每个帐户的检查点数映射[账户地址]
        uint32 nCheckpoints = numCheckpoints[account];
        // 返回 检查点 > 0 ? 选票检查点[账户地址][检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].票数 : 0
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice 确定帐户在指定区块前的投票数
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev 块号必须是已完成的块，否则此功能将还原以防止出现错误信息
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account 账户地址
     * @param blockNumber 区块号
     * @return 帐户在给定区块中所拥有的票数
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        // 确认 区块号 < 当前区块号
        require(blockNumber < block.number, "SUSHI::getPriorVotes: not yet determined");

        // 检查点数 = 每个帐户的检查点数映射[账户地址]
        uint32 nCheckpoints = numCheckpoints[account];
        // 如果检查点 == 0 返回 0
        if (nCheckpoints == 0) {
            return 0;
        }

        // 首先检查最近的余额
        // First check most recent balance
        // 如果 选票检查点[账户地址][检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].from块号 <= 区块号
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            // 返回 选票检查点[账户地址][检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].票数
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // 下一步检查隐式零余额
        // Next check implicit zero balance
        // 如果 选票检查点[账户地址][0].from块号 > 区块号 返回 0
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        // 通过二分查找找到检查点映射中from区块为给入区块号的检查点构造体中的票数
        // 如果没有则返回给入区块号之前最临近区块的检查点构造体的检查点数字
        uint32 lower = 0; //最小值0
        uint32 upper = nCheckpoints - 1; // 最大值(最后一个,索引从0开始,检查点数从1开始)
        while (upper > lower) { // 当最大值>最小值
            // 最大数与最小数之间的中间数 = 最大数 - (最大数 - 最小数) / 2
            uint32 center = upper - (upper - lower) / 2; // 防止溢出// ceil, avoiding overflow
            // 实例化检查点映射中用户索引值中间数对应的检查点构造体
            Checkpoint memory cp = checkpoints[account][center];
            // 如果 中间数构造体中的开始区块号 等于 传入的区块号
            if (cp.fromBlock == blockNumber) {
                // 返回中间数构造体中的票数
                return cp.votes;
            // 否则如果 中间数构造体中的开始区块号 小于 传入的区块号
            } else if (cp.fromBlock < blockNumber) {
                // 最小值 = 中间值
                lower = center;
                // 否则
            } else {
                // 最大值 = 中间数 - 1
                upper = center - 1;
            }
        }
        // 返回检查点映射中用户索引值为检查点数字的检查点构造体的票数
        return checkpoints[account][lower].votes;
    }

    /**
    * @dev 更换委托人
    * @param delegator 被委托人
    * @param delegatee 新委托人
     */
    function _delegate(address delegator, address delegatee)
        internal
    {
        // 被委托人的当前委托人
        address currentDelegate = _delegates[delegator];
        // 获取基础SUSHI的余额（未缩放）
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying SUSHIs (not scaled);
        // 修改被委托人的委托人为新委托人
        _delegates[delegator] = delegatee;

        // 触发更换委托人事件
        emit DelegateChanged(delegator, currentDelegate, delegatee);

        // 转移委托票数
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    /**
    * @dev 转移委托票数
    * @param srcRep 源地址
    * @param dstRep 目标地址
    * @param amount 转移的票数
     */
    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        // 如果源地址 != 目标地址 && 转移的票数 > 0
        if (srcRep != dstRep && amount > 0) {
            // 如果源地址 != 0地址 源地址不是0地址说明不是铸造方法
            if (srcRep != address(0)) {
                // 减少旧的代表
                // decrease old representative
                // 源地址的检查点数
                uint32 srcRepNum = numCheckpoints[srcRep];
                // 旧的源地址票数 = 源地址的检查点数 > 0 ? 选票检查点[源地址][源地址的检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].票数 : 0
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                // 新的源地址票数 = 旧的源地址票数 - 转移的票数
                uint256 srcRepNew = srcRepOld.sub(amount);
                // 写入检查点,修改委托人票数
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }
            // 如果目标地址 != 0地址 目标地址不是0地址说明不是销毁方法
            if (dstRep != address(0)) {
                // 增加新的代表
                // increase new representative
                // 目标地址检查点数
                uint32 dstRepNum = numCheckpoints[dstRep];
                // 旧目标地址票数 = 目标地址检查点数 > 0 ? 选票检查点[目标地址][目标地址的检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].票数 : 0
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                // 新目标地址票数 = 旧目标地址票数 + 转移的票数
                uint256 dstRepNew = dstRepOld.add(amount);
                // 写入检查点,修改委托人票数
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    /**
    * @dev 写入检查点
    * @param delegatee 委托人地址
    * @param nCheckpoints 检查点数
    * @param oldVotes 旧票数
    * @param newVotes 新票数
     */
    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        // 区块号 = 限制在32位2进制之内(当前区块号)
        uint32 blockNumber = safe32(block.number, "SUSHI::_writeCheckpoint: block number exceeds 32 bits");
        // 如果 检查点数 > 0 && 检查点映射[委托人][检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].from块号 == 当前区块号
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            // 检查点映射[委托人][检查点数 - 1(最后一个,索引从0开始,检查点数从1开始)].票数 = 新票数
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            // 检查点映射[委托人][检查点] = 检查点构造体(当前区块号, 新票数)
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            // 每个帐户的检查点数映射[委托人] = 检查点数 + 1
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }
        // 触发委托人票数更改事件
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    /**
    * @dev 安全的32位数字
    * @param n 输入数字
    * @param errorMessage 报错信息
     */
    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        // 确认 n < 2**32
        require(n < 2**32, errorMessage);
        // 返回n
        return uint32(n);
    }

    /**
    * @dev 获取链id
     */
    function getChainId() internal pure returns (uint) {
        // 定义chainId变量
        uint256 chainId;
        // 内联汇编取出chainId
        assembly { chainId := chainid() }
        // 返回chainId
        return chainId;
    }
}