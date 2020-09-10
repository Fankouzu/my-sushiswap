pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./uniswapv2/interfaces/IUniswapV2ERC20.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";
// SushiMaker 合约 地址:0x54844afe358Ca98E4D09AAe869f25bfe072E1B1a
contract SushiMaker {
    using SafeMath for uint256;
    //工厂合约地址
    IUniswapV2Factory public factory;
    //Sushi Bar地址
    address public bar;
    //Sushi Token地址
    address public sushi;
    //WETH地址
    address public weth;

    /**
    * @dev 构造函数
    * @param _factory 工厂合约地址
    * @param _bar Sushi Bar地址
    * @param _sushi Sushi Token地址
    * @param _weth WETH地址
     */
    //以下是SushiMaker合约布署时构造函数的参数
    // _factory:'0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac',
    // _bar:'0x8798249c2e607446efb7ad49ec89dd1865ff4272',
    // _sushi:'0x6b3595068778dd592e39a122f4f5a5cf09c90fe2',
    // _weth:'0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'
    constructor(
        IUniswapV2Factory _factory,
        address _bar,
        address _sushi,
        address _weth
    ) public {
        factory = _factory;
        sushi = _sushi;
        bar = _bar;
        weth = _weth;
    }

    /**
    * @dev 将token转换为sushi Token
    * @param token0 token0
    * @param token1 token1
     */
    function convert(address token0, address token1) public {
        // 至少我们尝试使前置运行变得更困难
        // At least we try to make front-running harder to do.
        // 确认合约调用者为初始调用用户
        require(msg.sender == tx.origin, "do not convert from contract");
        // 通过token0和token1找到配对合约地址,并实例化配对合约
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        // 调用配对合约的transfer方法,将当前合约的余额发送到配对合约地址上
        pair.transfer(address(pair), pair.balanceOf(address(this)));
        // 调用配对合约的销毁方法,将流动性token销毁,之后配对合约将会向当前合约地址发送token0和token1
        pair.burn(address(this));
        // 将token0和token1全部交换为WETH并发送到weth和SushiToken的配对合约上
        uint256 wethAmount = _toWETH(token0) + _toWETH(token1);
        // 将weth全部交换为SushiToken并发送到SushiBar合约上
        _toSUSHI(wethAmount);
    }

    /**
    * @dev 将token卖出转换为weth
    * @param token token
     */
    function _toWETH(address token) internal returns (uint256) {
        // 如果token地址是Sushi Token地址
        if (token == sushi) {
            // 数额 = 当前合约地址在token地址上的余额
            uint256 amount = IERC20(token).balanceOf(address(this));
            // 将数额从当前合约地址发送到sushiBar合约
            IERC20(token).transfer(bar, amount);
            // 返回0
            return 0;
        }
        // 如果token地址是WETH地址
        if (token == weth) {
            // 数额 = 当前合约地址在token地址上的余额
            uint256 amount = IERC20(token).balanceOf(address(this));
            // 将数额从当前合约发送到sushi布署的工厂合约上的WETH和SushiToken的配对合约地址上
            IERC20(token).transfer(factory.getPair(weth, sushi), amount);
            // 返回数额
            return amount;
        }
        // 实例化token地址和WETH地址的配对合约
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token, weth));
        // 如果配对合约地址 == 0地址 返回0
        if (address(pair) == address(0)) {
            return 0;
        }
        // 从配对合约获取储备量0,储备量1
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        // 找到token0
        address token0 = pair.token0();
        // 排序形成储备量In和储备量Out
        (uint256 reserveIn, uint256 reserveOut) = token0 == token
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        // 输入数额 = 当前合约地址在token地址的余额
        uint256 amountIn = IERC20(token).balanceOf(address(this));
        // 税后输入数额 = 输入数额 * 997
        uint256 amountInWithFee = amountIn.mul(997);
        // 分子 = 税后输入数额 * 储备量Out
        uint256 numerator = amountInWithFee.mul(reserveOut);
        // 分母 = 储备量In * 1000 + 税后输入数额
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        // 输出数额 = 分子 / 分母
        uint256 amountOut = numerator / denominator;
        // 排序输出数额0和输出数额1,有一个是0
        (uint256 amount0Out, uint256 amount1Out) = token0 == token
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        // 将输入数额发送到配对合约
        IERC20(token).transfer(address(pair), amountIn);
        // 执行配对合约的交换方法(输出数额0,输出数额1,发送到WETH和token的配对合约上)
        pair.swap(
            amount0Out,
            amount1Out,
            factory.getPair(weth, sushi),
            new bytes(0)
        );
        // 返回输出数额
        return amountOut;
    }

    /**
    * @dev 用amountIn数量的weth交换sushiToken并发送到sushiBar合约上
    * @param amountIn 输入数额
     */
    function _toSUSHI(uint256 amountIn) internal {
        // 获取SushiToken和WETH的配对合约地址,并实例化配对合约
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(weth, sushi));
        // 获取配对合约的储备量0,储备量1
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        // 找到token0
        address token0 = pair.token0();
        // 排序生成储备量In和储备量Out
        (uint256 reserveIn, uint256 reserveOut) = token0 == weth
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        // 税后输入数额 = 输入数额 * 997
        uint256 amountInWithFee = amountIn.mul(997);
        // 分子 = 税后输入数额 * 储备量Out
        uint256 numerator = amountInWithFee.mul(reserveOut);
        // 分母 = 储备量In * 1000 + 税后输入数额
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        // 输出数额 = 分子 / 分母
        uint256 amountOut = numerator / denominator;
        // 排序输出数额0和输出数额1,有一个是0
        (uint256 amount0Out, uint256 amount1Out) = token0 == weth
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));
        // 执行配对合约的交换方法(输出数额0,输出数额1,发送到SushiBar合约上)
        pair.swap(amount0Out, amount1Out, bar, new bytes(0));
    }
}
