// 从COMPOUND拷贝的治理协议
// COPIED FROM https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/GovernorAlpha.sol
// 版权所有2020 Compound Labs，Inc.
// Copyright 2020 Compound Labs, Inc.
// 如果满足以下条件，则允许以源代码和二进制形式进行重新分发和使用，无论是否经过修改，都可以：
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
// 1.源代码的重新分发必须保留上述版权声明，此条件列表和以下免责声明。
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2.以二进制形式重新分发必须在分发随附的文档和/或其他材料中复制上述版权声明，此条件列表以及以下免责声明。
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3.未经事先特别书面许可，不得使用版权所有者的名称或其贡献者的名字来认可或促销从该软件衍生的产品。
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
// 版权持有者和贡献者按“原样”提供此软件，不提供任何明示或暗示的担保，包括但不限于针对特定目的的适销性和适用性的暗示担保。在任何情况下，版权持有人或贡献者均不对任何直接，间接，偶发，特殊，专有或后果性的损害（包括但不限于，替代商品或服务的购买，使用，数据，或业务中断），无论基于合同，严格责任或侵权行为（包括疏忽或其他方式），无论是否出于任何责任，都应通过使用本软件的任何方式（即使已事先告知）进行了赔偿。
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Ctrl + f键可查看XXX的所有修改。
// Ctrl+f for XXX to see all the modifications.

// XXX: pragma solidity ^0.5.16;
pragma solidity 0.6.12;

// XXX: import "./SafeMath.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// 时间锁合约 地址 0x9a8541ddf3a932a9a922b607e9cf7301f1d47bd1
contract Timelock {
    using SafeMath for uint256;

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    // 过期时间 14天
    uint256 public constant GRACE_PERIOD = 14 days;
    // 最小延迟 2天
    uint256 public constant MINIMUM_DELAY = 2 days;
    // 最大延迟 30天
    uint256 public constant MAXIMUM_DELAY = 30 days;

    // 管理员地址
    address public admin;
    // 处理中的管理员
    address public pendingAdmin;
    // 延迟时间
    uint256 public delay;
    // 是否初始化管理员
    bool public admin_initialized;

    // 交易队列
    mapping(bytes32 => bool) public queuedTransactions;

    /**
     * @dev 构造函数
     * @param admin_ 管理员地址
     * @param delay_ 延迟时间
     */
    constructor(address admin_, uint256 delay_) public {
        require(
            delay_ >= MINIMUM_DELAY,
            "Timelock::constructor: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "Timelock::constructor: Delay must not exceed maximum delay."
        );

        admin = admin_;
        delay = delay_;
        admin_initialized = false;
    }

    // XXX: function() external payable { }
    receive() external payable {}

    /**
     * @dev 设置默认延迟时间方法
     * @param delay_ 延迟时间
     * @notice 这个方法只能由当前合约自身调用,也就是将设置延迟时间的方法推入执行队列后再执行
     */
    function setDelay(uint256 delay_) public {
        require(
            msg.sender == address(this),
            "Timelock::setDelay: Call must come from Timelock."
        );
        require(
            delay_ >= MINIMUM_DELAY,
            "Timelock::setDelay: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "Timelock::setDelay: Delay must not exceed maximum delay."
        );
        delay = delay_;

        emit NewDelay(delay);
    }

    /**
     * @dev 接受管理员方法
     */
    function acceptAdmin() public {
        require(
            msg.sender == pendingAdmin,
            "Timelock::acceptAdmin: Call must come from pendingAdmin."
        );
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    /**
     * @dev 设置处理中的管理员方法
     * @param pendingAdmin_ 待处理的管理员
     * @notice 第一次执行只能通过初始化管理员设置,只有执行只能通过当前合约自身执行
     */
    function setPendingAdmin(address pendingAdmin_) public {
        // allows one time setting of admin for deployment purposes
        if (admin_initialized) {
            require(
                msg.sender == address(this),
                "Timelock::setPendingAdmin: Call must come from Timelock."
            );
        } else {
            require(
                msg.sender == admin,
                "Timelock::setPendingAdmin: First call must come from admin."
            );
            admin_initialized = true;
        }
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    /**
     * @dev 交易队列
     * @param target 目标地址数组
     * @param value 值数组
     * @param signature 签名字符串数组
     * @param data 调用数据数组
     * @param eta 延迟时间
     * @notice 只能通过管理员执行(治理合约)
     */
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes32) {
        require(
            msg.sender == admin,
            "Timelock::queueTransaction: Call must come from admin."
        );
        require(
            eta >= getBlockTimestamp().add(delay),
            "Timelock::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /**
     * @dev 取消交易
     * @param target 目标地址数组
     * @param value 值数组
     * @param signature 签名字符串数组
     * @param data 调用数据数组
     * @param eta 延迟时间
     * @notice 只能通过管理员执行(治理合约)
     */
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(
            msg.sender == admin,
            "Timelock::cancelTransaction: Call must come from admin."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @dev 执行交易
     * @param target 目标地址数组
     * @param value 值数组
     * @param signature 签名字符串数组
     * @param data 调用数据数组
     * @param eta 延迟时间
     * @notice 只能通过管理员执行(治理合约)
     */
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable returns (bytes memory) {
        require(
            msg.sender == admin,
            "Timelock::executeTransaction: Call must come from admin."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        require(
            queuedTransactions[txHash],
            "Timelock::executeTransaction: Transaction hasn't been queued."
        );
        require(
            getBlockTimestamp() >= eta,
            "Timelock::executeTransaction: Transaction hasn't surpassed time lock."
        );
        require(
            getBlockTimestamp() <= eta.add(GRACE_PERIOD),
            "Timelock::executeTransaction: Transaction is stale."
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call.value(value)(
            callData
        );
        require(
            success,
            "Timelock::executeTransaction: Transaction execution reverted."
        );

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
