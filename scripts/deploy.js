const {ethers} = require("hardhat");
const dotenv = require('dotenv');
const {getDeployedAddresses, writeDeployedAddresses} = require("./helpers");

deployTogethInvestFactory()
    .then(() => {
        console.log("DONE");
        process.exit(0);
    })
    .catch(e => {
        console.error(e);
        process.exit(1);
    });

async function deployTogethInvestFactory() {
        // load .env
        const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();
    
        // get the deployed contracts
        const {directory, filename, contractAddresses} = getDeployedAddresses(CHAIN_NAME);
        // setup deployer wallet
        const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

        const {TogethDAOMultisig,  weth, allowedContracts} = config;
    
        //  Deploy AllowList
        console.log(`Deploy AllowList to ${CHAIN_NAME}`);
        const allowList = await deploy(deployer, 'AllowList');
        console.log(`Deployed AllowList to ${CHAIN_NAME}`);
    
        // Deploy TogethInvest Factory
        console.log(`Deploy TogethInvest Factory to ${CHAIN_NAME}`);
        const factory = await deploy(deployer,'TogethInvestFactory', [
            TogethDAOMultisig,
            weth,
            allowList.address
        ]);
        console.log(`Deployed TogethInvest Factory to ${CHAIN_NAME}: `, factory.address);
    
        // Setup Allowed Contracts
        for (let allowedContract of allowedContracts) {
            console.log(`Set Allowed ${allowedContract}`);
            await allowList.setAllowed(allowedContract, true);
        }
    
        // Transfer Ownership  of AllowList to TogethDAO multisig
        if (CHAIN_NAME == "mainnet") {
            console.log(`Transfer Ownership of AllowList on ${CHAIN_NAME}`);
            await allowList.transferOwnership(TogethDAOMultisig);
            console.log(`Transferred Ownership of AllowList on ${CHAIN_NAME}`);
        }
    
        // Get Logic address
        const logic = await factory.logic();
    
        // update the foundation market wrapper address
        contractAddresses["TogethInvestFactory"] = factory.address;
        contractAddresses["TogethInvestLogic"] = logic;
        contractAddresses["allowList"] = allowList.address;
    
        // write the updated object
        writeDeployedAddresses(directory, filename, contractAddresses);
}

function loadEnv() {
    dotenv.config();
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = process.env;
    if (!(CHAIN_NAME && RPC_ENDPOINT && DEPLOYER_PRIVATE_KEY)) {
        throw new Error("Please load all required parameters");
    }
    return {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY};
}

function getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY) {
    const provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
    const deployer = new ethers.Wallet(`0x${DEPLOYER_PRIVATE_KEY}`, provider);
    return deployer;
}