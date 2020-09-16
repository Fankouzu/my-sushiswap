const SushiMaker = artifacts.require("SushiMaker");
const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const SushiBar = artifacts.require("SushiBar");
const SushiToken = artifacts.require("SushiToken");
const WETH9 = artifacts.require("WETH9");

const weth = {
  mainnet: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
  ropsten: '0xc778417E063141139Fce010982780140Aa0cD5Ab',
  rinkeby: '0xc778417E063141139Fce010982780140Aa0cD5Ab',
  goerli: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',
  kovan: '0xd0A1E359811322d97991E03f863a0C30C2cF029C',
  ganache: ''
}
module.exports = async (deployer, network, accounts) => {
  const UniswapV2FactoryInstance = await UniswapV2Factory.deployed();
  const SushiBarInstance = await SushiBar.deployed();
  const SushiTokenInstance = await SushiToken.deployed();
  if(network == 'ganache'){
    const WETH9Instance = await deployer.deploy(WETH9);
    weth.ganache = WETH9Instance.address;
  }
  return deployer.deploy(SushiMaker,
    UniswapV2FactoryInstance.address, //工厂合约地址
    SushiBarInstance.address, //Sushi Bar地址
    SushiTokenInstance.address, //Sushi Token地址
    weth[network], //WETH地址
  ).then(async (SushiMakerInstance)=>{
    //设置交易手续费接收
    await UniswapV2FactoryInstance.setFeeTo(SushiMakerInstance.address);
    console.log(await UniswapV2FactoryInstance.feeTo());
  });
};