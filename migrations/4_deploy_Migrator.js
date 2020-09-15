const UniswapV2Factory = artifacts.require("UniswapV2Factory");
const MasterChef = artifacts.require("MasterChef");
const Migrator = artifacts.require("Migrator");

const UniswapFactoryAddress = '0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f';
module.exports = async (deployer, network, accounts) => {
  const UniswapV2FactoryInstance = await UniswapV2Factory.deployed();
  const MasterChefInstance = await MasterChef.deployed();
  return deployer.deploy(Migrator,
    MasterChefInstance.address, //主厨合约地址
    UniswapFactoryAddress, //旧工厂合约地址
    UniswapV2FactoryInstance.address, //新工厂合约
    '0', //不能早于的块号
  );
};