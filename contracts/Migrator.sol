pragma solidity 0.6.12;

import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";

// 迁移合约, 目前尚未部署,有消息称将采用新版本的迁移合约
contract Migrator {
    // 主厨合约地址
    address public chef;
    // 旧工厂合约地址
    address public oldFactory;
    // 新工厂合约
    IUniswapV2Factory public factory;

    // 不能早于的块号
    uint256 public notBeforeBlock;
    // 需求流动性数额 = 无限大
    uint256 public desiredLiquidity = uint256(-1);

    /**
    * @dev 构造函数
    * @param _chef 主厨合约地址
    * @param _oldFactory 旧工厂合约地址
    * @param _factory 新工厂合约
    * @param _notBeforeBlock 不能早于的块号
     */
    constructor(
        address _chef,
        address _oldFactory,
        IUniswapV2Factory _factory,
        uint256 _notBeforeBlock
    ) public {
        chef = _chef;
        oldFactory = _oldFactory;
        factory = _factory;
        notBeforeBlock = _notBeforeBlock;
    }

    /**
    * @dev 迁移方法
    * @param orig UniswapV2 旧配对合约地址
    * @return IUniswapV2Pair 配对合约地址
     */
    function migrate(IUniswapV2Pair orig) public returns (IUniswapV2Pair) {
        // 确认当前用户是主厨合约地址
        require(msg.sender == chef, "not from master chef");
        // 确认当前块号大于不能早于的块号
        require(block.number >= notBeforeBlock, "too early to migrate");
        // 确认配对合约的工厂合约地址 = 旧工厂合约地址
        require(orig.factory() == oldFactory, "not from old factory");
        // 定义token0和token1
        address token0 = orig.token0();
        address token1 = orig.token1();
        // 通过工厂合约的获取配对方法实例化配对合约
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        // 如果配对合约不存在
        if (pair == IUniswapV2Pair(address(0))) {
            // 配对合约地址 = 通过工厂合约地址创建配对合约
            pair = IUniswapV2Pair(factory.createPair(token0, token1));
        }
        // 流动性数量 = 当前用户在旧配对合约的余额
        uint256 lp = orig.balanceOf(msg.sender);
        // 如果流动性数量 = 0 返回配对合约地址
        if (lp == 0) return pair;
        // 需求流动性数额 = 流动性数量
        desiredLiquidity = lp;
        // 调用旧配对合约的发送方法,从主厨合约将流动性数量发送到旧配对合约
        orig.transferFrom(msg.sender, address(orig), lp);
        // 调用旧配对合约的销毁方法,将token0,token1发送到新配对合约
        orig.burn(address(pair));
        // 调用新配对合约铸造方法给主厨合约铸造新流动性token
        pair.mint(msg.sender);
        // 需求流动性数额 = 无限大
        desiredLiquidity = uint256(-1);
        // 返回配对合约地址
        return pair;
    }
}