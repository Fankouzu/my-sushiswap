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
// 为了简化和安全起见，将uint96s更改为uint256s。
// uint96s are changed to uint256s for simplicity and safety.

// XXX: pragma solidity ^0.5.16;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SushiToken.sol";
// 治理合约,目前尚未部署
contract GovernorAlpha {
    /// @notice 合约名称
    /// @notice The name of this contract
    // XXX：名称 = "Compound Governor Alpha"；
    // XXX: string public constant name = "Compound Governor Alpha";
    string public constant name = "Sushi Governor Alpha";

    /**
     * @notice 达到法定人数和投票成功所需要的支持提案的票数
     * @dev sushi.总供应 / 25
     */
    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    // XXX: function quorumVotes() public pure returns (uint) { return 400000e18; } // 400,000 = 4% of Comp
    function quorumVotes() public view returns (uint256) {
        return sushi.totalSupply() / 25;
    } // 4% of Supply

    /**
     * @notice 为使投票者成为提议者所需的投票数
     * @dev sushi.总供应 / 100
     */
    /// @notice The number of votes required in order for a voter to become a proposer
    // function proposalThreshold() public pure returns (uint) { return 100000e18; } // 100,000 = 1% of Comp
    function proposalThreshold() public view returns (uint256) {
        return sushi.totalSupply() / 100;
    } // 1% of Supply

    /**
     * @notice 提案中可以包含的最大操作数
     * @dev 返回10
     */
    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    } // 10 actions

    /**
     * @notice 一旦提议，投票表决可能会延迟
     * @dev 返回1
     */
    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256) {
        return 1;
    } // 1 block

    /**
     * @notice 对提案进行投票的持续时间（以块为单位）
     * @dev 返回 17280 约3天（假设15秒）
     */
    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint256) {
        return 17280;
    } // ~3 days in blocks (assuming 15s blocks)

    /// @notice 时间锁合约地址
    /// @notice The address of the Compound Protocol Timelock
    TimelockInterface public timelock;

    /// @notice SushiToken 合约地址
    /// @notice The address of the Compound governance token
    // XXX: CompInterface public comp;
    SushiToken public sushi;

    /// @notice 监护人地址
    /// @notice The address of the Governor Guardian
    address public guardian;

    /// @notice 总提案数量
    /// @notice The total number of proposals
    uint256 public proposalCount;

    // 提案构造体
    struct Proposal {
        // @notice 提案的唯一id
        // @notice Unique id for looking up a proposal
        uint256 id;
        // @notice 提案创建者
        // @notice Creator of the proposal
        address proposer;
        // @notice  提案可在表决成功后设置的时间戳
        // @notice  The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        // @notice  要进行调用的目标地址的有序列表
        // @notice  the ordered list of target addresses for calls to be made
        address[] targets;
        // @notice  要传递给要进行的调用的主币数量（即msg.value）的有序列表
        // @notice  The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        // @notice  要调用的功能签名的有序列表
        // @notice  The ordered list of function signatures to be called
        string[] signatures;
        // @notice  要传递给每个调用方法的调用数据的有序列表
        // @notice  The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        // @notice  开始投票的区块：持有人必须在此区块之前委派投票
        // @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        // @notice  投票结束的区块：必须在该区块之前进行投票
        // @notice  The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        // @notice  目前赞成该提案的票数
        // @notice  Current number of votes in favor of this proposal
        uint256 forVotes;
        // @notice  目前反对该提案的票数
        // @notice  Current number of votes in opposition to this proposal
        uint256 againstVotes;
        // @notice  标记该提案是否已被取消的标志
        // @notice  Flag marking whether the proposal has been canceled
        bool canceled;
        // @notice  标记该提案是否已执行的标志
        // @notice  Flag marking whether the proposal has been executed
        bool executed;
        // @notice  整个选民的选票收据
        // @notice  Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /// @notice 投票者选票收据构造体
    /// @notice Ballot receipt record for a voter
    struct Receipt {
        // @notice  是否已投票
        // @notice  Whether or not a vote has been cast
        bool hasVoted;
        // @notice  选民是否支持提案
        // @notice  Whether or not the voter supports the proposal
        bool support;
        // @notice  选民所投票的票数
        // @notice  The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice 提案可能处于的可能状态枚举
    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending, // 处理中
        Active, // 活跃
        Canceled, // 已取消
        Defeated, // 已失败
        Succeeded, // 已成功
        Queued, // 已排队
        Expired, // 已过期
        Executed // 已执行
    }

    /// @notice 曾经提出过的所有提案的正式记录
    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice 每个提案人的最新提案
    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice EIP-712的合约域hash
    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
    );

    /// @notice EIP-712的代理人构造体的hash
    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256(
        "Ballot(uint256 proposalId,bool support)"
    );

    /// @notice 新提案事件
    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice 对提案进行投票时发出的事件
    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(
        address voter,
        uint256 proposalId,
        bool support,
        uint256 votes
    );

    /// @notice 取消提案后发出的事件
    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice 当提案已在时间锁中排队时发出的事件
    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice 在时间锁中执行投标后发出的事件
    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    /**
     * @dev 构造函数
     * @param timelock_ 时间锁合约地址
     * @param sushi_ SushiToken 合约地址
     * @param guardian_ 监护人地址
     */
    constructor(
        address timelock_,
        address sushi_,
        address guardian_
    ) public {
        timelock = TimelockInterface(timelock_);
        sushi = SushiToken(sushi_);
        guardian = guardian_;
    }

    /**
     * @dev 提案方法
     * @param targets 目标地址数组
     * @param values 主币数量数组
     * @param signatures 签名字符串数组
     * @param calldatas 调用数据数组
     * @param description 说明
     * @notice 将提案写入构提案造体,并推入提案数组,发起人的提案id++
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(
            sushi.getPriorVotes(msg.sender, sub256(block.number, 1)) >
                proposalThreshold(),
            "GovernorAlpha::propose: proposer votes below proposal threshold"
        );
        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "GovernorAlpha::propose: proposal function information arity mismatch"
        );
        require(
            targets.length != 0,
            "GovernorAlpha::propose: must provide actions"
        );
        require(
            targets.length <= proposalMaxOperations(),
            "GovernorAlpha::propose: too many actions"
        );

        uint256 latestProposalId = latestProposalIds[msg.sender];
        // 如果发起人之前有过提案,则之前的提案必须已经关闭
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "GovernorAlpha::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        uint256 startBlock = add256(block.number, votingDelay());
        uint256 endBlock = add256(startBlock, votingPeriod());

        proposalCount++;
        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return newProposal.id;
    }

    /**
     * @dev 队列方法
     * @param proposalId 提案ID
     * @notice 将已经成功的提案推入时间锁合约的执行队列中
     */
    function queue(uint256 proposalId) public {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "GovernorAlpha::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];
        uint256 eta = add256(block.timestamp, timelock.delay());
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _queueOrRevert(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @dev 插入时间锁队列
     * @param target 目标地址
     * @param value 主币数量
     * @param signature 签名
     * @param data 数据
     * @param eta 时间
     * @notice 将已经成功的提案推入时间锁合约的执行队列中
     */
    function _queueOrRevert(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !timelock.queuedTransactions(
                keccak256(abi.encode(target, value, signature, data, eta))
            ),
            "GovernorAlpha::_queueOrRevert: proposal action already queued at eta"
        );
        timelock.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @dev 执行操作
     * @param proposalId 提案ID
     * @notice 将队列中的提案推入到时间锁合约的执行方法中
     */
    function execute(uint256 proposalId) public payable {
        require(
            state(proposalId) == ProposalState.Queued,
            "GovernorAlpha::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction.value(proposal.values[i])(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev 取消提案
     * @param proposalId 提案ID
     * @notice 将提案推入到时间锁合约的取消方法中
     */
    function cancel(uint256 proposalId) public {
        ProposalState state = state(proposalId);
        require(
            state != ProposalState.Executed,
            "GovernorAlpha::cancel: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == guardian ||
                sushi.getPriorVotes(
                    proposal.proposer,
                    sub256(block.number, 1)
                ) <
                proposalThreshold(),
            "GovernorAlpha::cancel: proposer above threshold"
        );

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @dev 获取动作
     * @param proposalId 提案ID
     * @notice 获取提案中的动作
     */
    function getActions(uint256 proposalId)
        public
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        )
    {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    /**
     * @dev 获取收据
     * @param proposalId 提案ID
     * @param voter 投票人地址
     * @notice 获取提案中指定投票人的收据
     */
    function getReceipt(uint256 proposalId, address voter)
        public
        view
        returns (Receipt memory)
    {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @dev 提案状态
     * @param proposalId 提案ID
     * @notice 返回提案当前状态
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId && proposalId > 0,
            "GovernorAlpha::state: invalid proposal id"
        );
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < quorumVotes()
        ) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            block.timestamp >= add256(proposal.eta, timelock.GRACE_PERIOD())
        ) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @dev 投票方法
     * @param proposalId 提案ID
     * @param support 是否支持
     */
    function castVote(uint256 proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    /**
     * @dev 带签名的投票方法
     * @param proposalId 提案ID
     * @param support 是否支持
     * @param v 签名的恢复字节
     * @param r ECDSA签名对的一半 
     * @param s ECDSA签名对的一半 
     * @notice 使用签名还原的帐号投票
     */
    function castVoteBySig(
        uint256 proposalId,
        bool support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainId(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "GovernorAlpha::castVoteBySig: invalid signature"
        );
        return _castVote(signatory, proposalId, support);
    }

    /**
     * @dev 投票方法
     * @param voter 投票人
     * @param proposalId 提案ID
     * @param support 是否支持
     * @notice 调用sushiToken中投票人的票数进行投票,将票数记录在收据构造体中
     */
    function _castVote(
        address voter,
        uint256 proposalId,
        bool support
    ) internal {
        require(
            state(proposalId) == ProposalState.Active,
            "GovernorAlpha::_castVote: voting is closed"
        );
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(
            receipt.hasVoted == false,
            "GovernorAlpha::_castVote: voter already voted"
        );
        uint256 votes = sushi.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = add256(proposal.forVotes, votes);
        } else {
            proposal.againstVotes = add256(proposal.againstVotes, votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    /**
     * @dev 接受管理员
     * @notice 接受并成为时间锁合约的管理员
     */
    function __acceptAdmin() public {
        require(
            msg.sender == guardian,
            "GovernorAlpha::__acceptAdmin: sender must be gov guardian"
        );
        timelock.acceptAdmin();
    }

    /**
     * @dev 放弃方法
     * @notice 当治理合约成为时间锁合约管理员之后,放弃管理员的权限
     */
    function __abdicate() public {
        require(
            msg.sender == guardian,
            "GovernorAlpha::__abdicate: sender must be gov guardian"
        );
        guardian = address(0);
    }

    /**
     * @dev 更换时间锁管理员
     * @param newPendingAdmin 新管理员
     * @param eta 执行时间
     * @notice 将设置时间锁管理员的操作推入时间锁合约的队列中
     */
    function __queueSetTimelockPendingAdmin(
        address newPendingAdmin,
        uint256 eta
    ) public {
        require(
            msg.sender == guardian,
            "GovernorAlpha::__queueSetTimelockPendingAdmin: sender must be gov guardian"
        );
        timelock.queueTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

    /**
     * @dev 执行更换时间锁管理员
     * @param newPendingAdmin 新管理员
     * @param eta 执行时间
     * @notice 执行设置时间锁管理员的操作
     */
    function __executeSetTimelockPendingAdmin(
        address newPendingAdmin,
        uint256 eta
    ) public {
        require(
            msg.sender == guardian,
            "GovernorAlpha::__executeSetTimelockPendingAdmin: sender must be gov guardian"
        );
        timelock.executeTransaction(
            address(timelock),
            0,
            "setPendingAdmin(address)",
            abi.encode(newPendingAdmin),
            eta
        );
    }

    function add256(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "addition overflow");
        return c;
    }

    function sub256(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint256);

    function GRACE_PERIOD() external view returns (uint256);

    function acceptAdmin() external;

    function queuedTransactions(bytes32 hash) external view returns (bool);

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory);
}
