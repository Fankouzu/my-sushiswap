#!/usr/bin/env node

const fs = require('fs');
const inquirer = require('inquirer');
const ethers = require("ethers");
const Web3 = require("web3");
const bip39 = require('bip39');
const HDWalletProvider = require('@truffle/hdwallet-provider');
const {
    spawn
} = require('child_process');

let contractsAddress = {
    SushiToken: '',
    MasterChef: ''
}
let accounts = [];
let web3;

validateMnemonic = (mnemonic) => {
    if (mnemonic !== '') {
        if (lngDetector(mnemonic)) {
            return bip39.validateMnemonic(mnemonic, bip39.wordlists.EN)
        } else {
            return bip39.validateMnemonic(mnemonic.replace(/ /g, '').split('').join(' '), bip39.wordlists.chinese_simplified)
        }
    } else {
        return false
    }
}
lngDetector = (word) => {
    var regex = new RegExp('^([a-z]{0,200})$')
    return regex.test(word.replace(/ /g, ''))
}

const network = async () => {
    inquirer.prompt([{
                type: 'list',
                name: 'network',
                message: '选择网络 :',
                choices: [{
                        name: "ganache cli 测试环境",
                        value: "ganache"
                    },
                    {
                        name: "Ropsten 测试网",
                        value: "ropsten"
                    },
                    {
                        name: "Rinkeby 测试网",
                        value: "rinkeby"
                    },
                    {
                        name: "Kovan 测试网",
                        value: "kovan"
                    },
                    {
                        name: "以太坊主网",
                        value: "mainnet"
                    },
                ],
            }
        ])
        .then(answers => {
            if (answers.network === "ganache") {
                web3 = new Web3('http://localhost:7545');
            } else {
                const mnemonic = fs.readFileSync(".mnemonic").toString().trim();
                const infuraKey = fs.readFileSync(".infuraKey").toString().trim();
    //             let infuraProvider = new ethers.providers.InfuraProvider()
    //             let privateKey = mnemonicToPrivate(mnemonic, currentAccount)
    // let wallet = new ethers.Wallet(privateKey, infuraProvider)
    // let factory = new ethers.ContractFactory(abi, bytecode, wallet)
                web3 = new Web3(new HDWalletProvider(mnemonic, 'https://'+answers.network+'.infura.io/v3/' + infuraKey));
            }
            main()
        });
}

const deploy = async (contract, arguments) => {
    const {
        abi,
        bytecode
    } = require('../build/contracts/' + contract + '.json');
    const myContract = new web3.eth.Contract(abi);
    console.log('from Address:', accounts[0])
    myContract.deploy({
            data: bytecode,
            arguments: arguments
        })
        .send({
            from: accounts[0],
            gas: 6000000
        })
        .then(function (newContractInstance) {
            console.log('合约地址:', newContractInstance.options.address);
            contractsAddress[contract] = newContractInstance.options.address;
            main()
        });
}

const main = async () => {
    accounts = await web3.eth.getAccounts();
    console.log('==================================================================')
    inquirer.prompt([{
            type: 'list',
            name: 'step1',
            message: '选择要布署的合约',
            choices: [{
                    name: "布署SushiToken",
                    value: 'SushiToken'
                },
                {
                    name: "MasterChef主厨合约",
                    value: 'MasterChef'
                },
                {
                    name: "布署Uniswap工厂合约",
                    value: 'Factory'
                },
                {
                    name: "布署Uniswap路由合约",
                    value: 'Router'
                },
                {
                    name: "布署迁移合约",
                    value: 'Migrator'
                },
                {
                    name: "SushiBar合约",
                    value: 'SushiBar'
                },
                {
                    name: "SushiMaker合约",
                    value: 'SushiMaker'
                },
            ],
        }])
        .then(async (answers) => {
            switch (answers.step1) {
                case 'SushiToken':
                    await deploy('SushiToken', []);
                    break;
                case 'MasterChef':
                    deployMasterChef();
                    break;
                case 'Factory':
                    deployFactory();
                    break;
                case 'Router':
                    deployRouter();
                    break;
                case 'Migrator':
                    deployMigrator();
                    break;
                case 'SushiBar':
                    deploySushiBar();
                    break;
                case 'SushiMaker':
                    deploySushiMaker();
                    break;
            }
        });
};

const deployMasterChef = function () {
    console.log('==================================================================')
    inquirer.prompt([{
                type: 'input',
                message: "SushiToken地址",
                name: '_sushi',
                validate: function (value) {
                    if (Web3.utils.isAddress(value)) {
                        return true;
                    }
                    return '地址输入不正确';
                },
                default: function () {
                    return contractsAddress.SushiToken;
                }
            },
            {
                type: 'input',
                message: "开发者账号",
                name: '_devaddr',
                validate: function (value) {
                    if (Web3.utils.isAddress(value)) {
                        return true;
                    }
                    return '地址输入不正确';
                },
                default: function () {
                    return accounts[0];
                }
            },
            {
                type: 'input',
                message: "每块创建的SUSHI令牌",
                name: '_sushiPerBlock',
                default: function () {
                    return '100000000000000000000';
                }
            },
            {
                type: 'input',
                message: "SUSHI挖掘开始时的块号",
                name: '_startBlock',
                default: async function () {
                    return await web3.eth.getBlockNumber();
                }
            },
            {
                type: 'input',
                message: "奖励结束块号",
                name: '_bonusEndBlock',
                default: async function () {
                    return await web3.eth.getBlockNumber() + 100000;
                }
            }
        ], )
        .then(async (answers) => {
            await deploy('MasterChef', [
                answers._sushi,
                answers._devaddr,
                answers._sushiPerBlock,
                answers._startBlock,
                answers._bonusEndBlock
            ]);
        });
};

const deployFactory = function () {
    console.log('==================================================================')
    inquirer.prompt([{
            type: 'input',
            message: "_feeToSetter地址",
            name: '_feeToSetter',
            validate: function (value) {
                if (Web3.utils.isAddress(value)) {
                    return true;
                }
                return '地址输入不正确';
            },
            default: function () {
                return contractsAddress.SushiToken;
            }
        }], )
        .then(async (answers) => {
            await deploy('UniswapV2Factory', [
                answers._feeToSetter
            ]);
        });
};

const deployRouter = function () {
    console.log('==================================================================')
    inquirer.prompt([{
            type: 'input',
            message: "_feeToSetter地址",
            name: '_feeToSetter',
            validate: function (value) {
                if (Web3.utils.isAddress(value)) {
                    return true;
                }
                return '地址输入不正确';
            },
            default: function () {
                return contractsAddress.SushiToken;
            }
        }], )
        .then(async (answers) => {
            await deploy('UniswapV2Factory', [
                answers._feeToSetter
            ]);
        });
};
network();