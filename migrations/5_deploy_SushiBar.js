const SushiBar = artifacts.require("SushiBar");
const SushiToken = artifacts.require("SushiToken");

module.exports = async (deployer, network, accounts) => {
  const SushiTokenInstance = await SushiToken.deployed();
  return deployer.deploy(SushiBar,
    SushiTokenInstance.address //SushiToken合约地址
  );
};