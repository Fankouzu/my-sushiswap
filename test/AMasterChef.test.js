const { expectRevert, time } = require('@openzeppelin/test-helpers');
const SushiToken = artifacts.require('SushiToken');
const MasterChef = artifacts.require('MasterChef');
const MockERC20 = artifacts.require('MockERC20');

// 测试主厨合约,生成5个帐号
contract('MasterChef', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {// 每次重新部署SushiToken合约,以alice身份
        this.sushi = await SushiToken.new({ from: alice });
    });

    it('验证正确的状态变量', async () => {
        // 部署主厨合约
        // 参数:(SushiToken地址,dev帐号,每块创建1000个SUSHI令牌,SUSHI挖掘在0块开始,奖励在1000块结束)
        // 以alice身份部署
        this.chef = await MasterChef.new(this.sushi.address, dev, '1000', '0', '1000', { from: alice });
        // alice将SushiToken的Owner身份转移给主厨合约地址
        await this.sushi.transferOwnership(this.chef.address, { from: alice });
        // SushiToken地址
        const sushi = await this.chef.sushi();
        // 开发者帐号地址
        const devaddr = await this.chef.devaddr();
        // owner地址
        const owner = await this.sushi.owner();
        //验证
        assert.equal(sushi.valueOf(), this.sushi.address);
        assert.equal(devaddr.valueOf(), dev);
        assert.equal(owner.valueOf(), this.chef.address);
    });

    it('验证开发者帐号权限', async () => {
        // 部署主厨合约
        // 参数:(SushiToken地址,dev帐号,每块创建1000个SUSHI令牌,SUSHI挖掘在0块开始,奖励在1000块结束)
        // 以alice身份部署
        this.chef = await MasterChef.new(this.sushi.address, dev, '1000', '0', '1000', { from: alice });
        // 验证开发者帐号地址
        assert.equal((await this.chef.devaddr()).valueOf(), dev);
        // 错误帐号设置开发者帐号
        await expectRevert(this.chef.dev(bob, { from: bob }), 'dev: wut?');
        // 将开发者帐号设置为bob
        await this.chef.dev(bob, { from: dev });
        // 验证新开发者帐号
        assert.equal((await this.chef.devaddr()).valueOf(), bob);
        // 再次修改开发者帐号
        await this.chef.dev(alice, { from: bob });
        // 验证新开发者帐号
        assert.equal((await this.chef.devaddr()).valueOf(), alice);
    })

    context('With ERC/LP token added to the field', () => {
        beforeEach(async () => {// 每次验证之前执行
            // lp = 部署模拟erc20('LPToken', 'LP', '10000000000')
            this.lp = await MockERC20.new('LPToken', 'LP', '10000000000', { from: minter });
            // 将1000个lp从minter发送到alice账户
            await this.lp.transfer(alice, '1000', { from: minter });
            // 将1000个lp从minter发送到bob账户
            await this.lp.transfer(bob, '1000', { from: minter });
            // 将1000个lp从minter发送到carol账户
            await this.lp.transfer(carol, '1000', { from: minter });
            // lp2 = 部署模拟erc20('LPToken2', 'LP2', '10000000000')
            this.lp2 = await MockERC20.new('LPToken2', 'LP2', '10000000000', { from: minter });
            // 将1000个lp2从minter发送到alice账户
            await this.lp2.transfer(alice, '1000', { from: minter });
            // 将1000个lp2从minter发送到bob账户
            await this.lp2.transfer(bob, '1000', { from: minter });
            // 将1000个lp2从minter发送到carol账户
            await this.lp2.transfer(carol, '1000', { from: minter });
        });

        it('验证紧急撤出', async () => {
            // 每块100的耕种率，从第100块开始，直到第1000块为止 
            // 100 per block farming rate starting at block 100 with bonus until block 1000
            // 部署主厨合约
            // 参数:(SushiToken地址,dev帐号,每块创建100个SUSHI令牌,SUSHI挖掘在100块开始,奖励在1000块结束)
            // 以alice身份部署
            this.chef = await MasterChef.new(this.sushi.address, dev, '100', '100', '1000', { from: alice });
            // 将新的lp添加到池中,参数:(分配给该池的分配点数100,lp地址,触发更新所有池的奖励变量)
            await this.chef.add('100', this.lp.address, true);
            // bob批准主厨合约拥有1000个token权限
            await this.lp.approve(this.chef.address, '1000', { from: bob });
            // bob将100个LP令牌存入主厨合约进行SUSHI分配
            await this.chef.deposit(0, '100', { from: bob });
            // 验证当前bob的lp余额为900
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '900');
            // 调用紧急提款方法,由bob调用,取出lp
            await this.chef.emergencyWithdraw(0, { from: bob });
            // 验证当前bob的lp余额为1000
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '1000');
        });

        it('验证耕种时间过后才可以收到SUSHIs', async () => {
            // 每块100的耕种率，从第100块开始，直到第1000块为止
            // 100 per block farming rate starting at block 100 with bonus until block 1000
            // 部署主厨合约
            // 参数:(SushiToken地址,dev帐号,每块创建100个SUSHI令牌,SUSHI挖掘在100块开始,奖励在1000块结束)
            // 以alice身份部署
            this.chef = await MasterChef.new(this.sushi.address, dev, '100', '100', '1000', { from: alice });
            // 将sushi的owner转移给主厨合约
            await this.sushi.transferOwnership(this.chef.address, { from: alice });
            // 将新的lp添加到池中,参数:(分配给该池的分配点数100,lp地址,触发更新所有池的奖励变量)
            await this.chef.add('100', this.lp.address, true);
            // bob批准主厨合约拥有1000个token权限
            await this.lp.approve(this.chef.address, '1000', { from: bob });
            // bob将100个LP令牌存入主厨合约进行SUSHI分配
            await this.chef.deposit(0, '100', { from: bob });
            // 时间推移到89块
            await time.advanceBlockTo('89');
            // bob将0个LP令牌存入主厨合约进行SUSHI分配,当前块号到达90
            await this.chef.deposit(0, '0', { from: bob }); // block 90
            // 验证bob在sushi的余额为0
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '0');
            // 时间推移到94块
            await time.advanceBlockTo('94');
            // bob将0个LP令牌存入主厨合约进行SUSHI分配,当前块号到达95
            await this.chef.deposit(0, '0', { from: bob }); // block 95
            // 验证bob在sushi的余额为0
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '0');
            // 时间推移到99块
            await time.advanceBlockTo('99');
            // bob将0个LP令牌存入主厨合约进行SUSHI分配,当前块号到达100
            await this.chef.deposit(0, '0', { from: bob }); // block 100
            // 验证bob在sushi的余额为0
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '0');
            // 时间推移到100块
            await time.advanceBlockTo('100');
            // bob将0个LP令牌存入主厨合约进行SUSHI分配,当前块号到达101
            await this.chef.deposit(0, '0', { from: bob }); // block 101
            // 验证bob在sushi的余额为1000
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '1000');
            // 时间推移到104块
            await time.advanceBlockTo('104');
            // bob将0个LP令牌存入主厨合约进行SUSHI分配,当前块号到达105
            await this.chef.deposit(0, '0', { from: bob }); // block 105
            // 验证bob在sushi的余额为5000
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '5000');
            // 验证开发者帐号在sushi的余额为500
            assert.equal((await this.sushi.balanceOf(dev)).valueOf(), '500');
            // 验证sushi的总量为5500
            assert.equal((await this.sushi.totalSupply()).valueOf(), '5500');
        });

        it('验证如果没有人存款，则不应该分发SUSHIs', async () => {
            // 每块100的耕种率，从第200块开始，直到第1000块为止
            // 100 per block farming rate starting at block 200 with bonus until block 1000
            // 部署主厨合约
            // 参数:(SushiToken地址,dev帐号,每块创建100个SUSHI令牌,SUSHI挖掘在200块开始,奖励在1000块结束)
            // 以alice身份部署
            this.chef = await MasterChef.new(this.sushi.address, dev, '100', '200', '1000', { from: alice });
            // 将sushi的owner转移给主厨合约
            await this.sushi.transferOwnership(this.chef.address, { from: alice });
            // 将新的lp添加到池中,参数:(分配给该池的分配点数100,lp地址,触发更新所有池的奖励变量)
            await this.chef.add('100', this.lp.address, true);
            // bob批准主厨合约拥有1000个token权限
            await this.lp.approve(this.chef.address, '1000', { from: bob });
            // 时间推移到199块
            await time.advanceBlockTo('199');
            // 验证sushi的总量为0
            assert.equal((await this.sushi.totalSupply()).valueOf(), '0');
            // 时间推移到204块
            await time.advanceBlockTo('204');
            // 验证sushi的总量为0
            assert.equal((await this.sushi.totalSupply()).valueOf(), '0');
            // 时间推移到209块
            await time.advanceBlockTo('209');
            // bob将10个LP令牌存入主厨合约进行SUSHI分配,当前块号到达210
            await this.chef.deposit(0, '10', { from: bob }); // block 210
            // 验证sushi的总量为0
            assert.equal((await this.sushi.totalSupply()).valueOf(), '0');
            // 验证bob在sushi的余额为0
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '0');
            // 验证开发者帐号在sushi的余额为0
            assert.equal((await this.sushi.balanceOf(dev)).valueOf(), '0');
            // 验证bob在lp的余额为990
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '990');
            // 时间推移到219块
            await time.advanceBlockTo('219');
            // bob将10个LP令牌从主厨合约取出,当前块号到达220
            await this.chef.withdraw(0, '10', { from: bob }); // block 220
            // 验证sushi的总量为11000
            assert.equal((await this.sushi.totalSupply()).valueOf(), '11000');
            // 验证bob在sushi的余额为10000
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '10000');
            // 验证开发者帐号在sushi的余额为1000
            assert.equal((await this.sushi.balanceOf(dev)).valueOf(), '1000');
            // 验证bob在lp的余额为1000
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '1000');
        });

        it('should distribute SUSHIs properly for each staker', async () => {
            // 100 per block farming rate starting at block 300 with bonus until block 1000
            this.chef = await MasterChef.new(this.sushi.address, dev, '100', '300', '1000', { from: alice });
            await this.sushi.transferOwnership(this.chef.address, { from: alice });
            await this.chef.add('100', this.lp.address, true);
            await this.lp.approve(this.chef.address, '1000', { from: alice });
            await this.lp.approve(this.chef.address, '1000', { from: bob });
            await this.lp.approve(this.chef.address, '1000', { from: carol });
            // Alice deposits 10 LPs at block 310
            await time.advanceBlockTo('309');
            await this.chef.deposit(0, '10', { from: alice });
            // Bob deposits 20 LPs at block 314
            await time.advanceBlockTo('313');
            await this.chef.deposit(0, '20', { from: bob });
            // Carol deposits 30 LPs at block 318
            await time.advanceBlockTo('317');
            await this.chef.deposit(0, '30', { from: carol });
            // Alice deposits 10 more LPs at block 320. At this point:
            //   Alice should have: 4*1000 + 4*1/3*1000 + 2*1/6*1000 = 5666
            //   MasterChef should have the remaining: 10000 - 5666 = 4334
            await time.advanceBlockTo('319')
            await this.chef.deposit(0, '10', { from: alice });
            assert.equal((await this.sushi.totalSupply()).valueOf(), '11000');
            assert.equal((await this.sushi.balanceOf(alice)).valueOf(), '5666');
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '0');
            assert.equal((await this.sushi.balanceOf(carol)).valueOf(), '0');
            assert.equal((await this.sushi.balanceOf(this.chef.address)).valueOf(), '4334');
            assert.equal((await this.sushi.balanceOf(dev)).valueOf(), '1000');
            // Bob withdraws 5 LPs at block 330. At this point:
            //   Bob should have: 4*2/3*1000 + 2*2/6*1000 + 10*2/7*1000 = 6190
            await time.advanceBlockTo('329')
            await this.chef.withdraw(0, '5', { from: bob });
            assert.equal((await this.sushi.totalSupply()).valueOf(), '22000');
            assert.equal((await this.sushi.balanceOf(alice)).valueOf(), '5666');
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '6190');
            assert.equal((await this.sushi.balanceOf(carol)).valueOf(), '0');
            assert.equal((await this.sushi.balanceOf(this.chef.address)).valueOf(), '8144');
            assert.equal((await this.sushi.balanceOf(dev)).valueOf(), '2000');
            // Alice withdraws 20 LPs at block 340.
            // Bob withdraws 15 LPs at block 350.
            // Carol withdraws 30 LPs at block 360.
            await time.advanceBlockTo('339')
            await this.chef.withdraw(0, '20', { from: alice });
            await time.advanceBlockTo('349')
            await this.chef.withdraw(0, '15', { from: bob });
            await time.advanceBlockTo('359')
            await this.chef.withdraw(0, '30', { from: carol });
            assert.equal((await this.sushi.totalSupply()).valueOf(), '55000');
            assert.equal((await this.sushi.balanceOf(dev)).valueOf(), '5000');
            // Alice should have: 5666 + 10*2/7*1000 + 10*2/6.5*1000 = 11600
            assert.equal((await this.sushi.balanceOf(alice)).valueOf(), '11600');
            // Bob should have: 6190 + 10*1.5/6.5 * 1000 + 10*1.5/4.5*1000 = 11831
            assert.equal((await this.sushi.balanceOf(bob)).valueOf(), '11831');
            // Carol should have: 2*3/6*1000 + 10*3/7*1000 + 10*3/6.5*1000 + 10*3/4.5*1000 + 10*1000 = 26568
            assert.equal((await this.sushi.balanceOf(carol)).valueOf(), '26568');
            // All of them should have 1000 LPs back.
            assert.equal((await this.lp.balanceOf(alice)).valueOf(), '1000');
            assert.equal((await this.lp.balanceOf(bob)).valueOf(), '1000');
            assert.equal((await this.lp.balanceOf(carol)).valueOf(), '1000');
        });

        it('should give proper SUSHIs allocation to each pool', async () => {
            // 100 per block farming rate starting at block 400 with bonus until block 1000
            this.chef = await MasterChef.new(this.sushi.address, dev, '100', '400', '1000', { from: alice });
            await this.sushi.transferOwnership(this.chef.address, { from: alice });
            await this.lp.approve(this.chef.address, '1000', { from: alice });
            await this.lp2.approve(this.chef.address, '1000', { from: bob });
            // Add first LP to the pool with allocation 1
            await this.chef.add('10', this.lp.address, true);
            // Alice deposits 10 LPs at block 410
            await time.advanceBlockTo('409');
            await this.chef.deposit(0, '10', { from: alice });
            // Add LP2 to the pool with allocation 2 at block 420
            await time.advanceBlockTo('419');
            await this.chef.add('20', this.lp2.address, true);
            // Alice should have 10*1000 pending reward
            assert.equal((await this.chef.pendingSushi(0, alice)).valueOf(), '10000');
            // Bob deposits 10 LP2s at block 425
            await time.advanceBlockTo('424');
            await this.chef.deposit(1, '5', { from: bob });
            // Alice should have 10000 + 5*1/3*1000 = 11666 pending reward
            assert.equal((await this.chef.pendingSushi(0, alice)).valueOf(), '11666');
            await time.advanceBlockTo('430');
            // At block 430. Bob should get 5*2/3*1000 = 3333. Alice should get ~1666 more.
            assert.equal((await this.chef.pendingSushi(0, alice)).valueOf(), '13333');
            assert.equal((await this.chef.pendingSushi(1, bob)).valueOf(), '3333');
        });

        it('should stop giving bonus SUSHIs after the bonus period ends', async () => {
            // 100 per block farming rate starting at block 500 with bonus until block 600
            this.chef = await MasterChef.new(this.sushi.address, dev, '100', '500', '600', { from: alice });
            await this.sushi.transferOwnership(this.chef.address, { from: alice });
            await this.lp.approve(this.chef.address, '1000', { from: alice });
            await this.chef.add('1', this.lp.address, true);
            // Alice deposits 10 LPs at block 590
            await time.advanceBlockTo('589');
            await this.chef.deposit(0, '10', { from: alice });
            // At block 605, she should have 1000*10 + 100*5 = 10500 pending.
            await time.advanceBlockTo('605');
            assert.equal((await this.chef.pendingSushi(0, alice)).valueOf(), '10500');
            // At block 606, Alice withdraws all pending rewards and should get 10600.
            await this.chef.deposit(0, '0', { from: alice });
            assert.equal((await this.chef.pendingSushi(0, alice)).valueOf(), '0');
            assert.equal((await this.sushi.balanceOf(alice)).valueOf(), '10600');
        });
    });
});
