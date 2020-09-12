const SushiToken = artifacts.require("SushiToken");
// 布署SushiToken
module.exports = function(deployer) {
  deployer.deploy(SushiToken);
};
