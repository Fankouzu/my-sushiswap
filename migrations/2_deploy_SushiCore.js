const SushiToken = artifacts.require("SushiToken");
const MasterChef = artifacts.require("MasterChef");

module.exports = function(deployer,network,accounts) {
  // 布署SushiToken
  deployer.deploy(SushiToken).then(async (SushiTokenInstance)=>{
    const blockNumber = await web3.eth.getBlockNumber()
    // 布署主厨合约
    return deployer.deploy(MasterChef,
      SushiTokenInstance.address, //sushiToken地址
      accounts[0], //开发人员地址
      '100000000000000000000', //每块创建的SUSHI令牌
      blockNumber.toString(), //SUSHI挖掘开始时的块号
      (blockNumber+100000).toString() //奖励结束块号
      ).then(async (MasterChefInstance)=>{
        //将SushiToken的Owner权限交给主厨合约
        await SushiTokenInstance.transferOwnership(MasterChefInstance.address);
        console.log(await SushiTokenInstance.owner());
      });
  });
};
