// npx hardhat run --network rinkeby scripts/deploy_tokens.js
// npx hardhat verify --network rinkeby 0xe27785F96C0190840C71D64Aa83b35c90E9A0405 "1000000000000000000000000" "UNI-LP Token" "UNI-LP"

const hre = require("hardhat");
const dotenv = require('dotenv');
const network = hre.network.name;
const fs = require('fs');
const envConfig = dotenv.parse(fs.readFileSync(`.env`));
for (const k in envConfig) {
    process.env[k] = envConfig[k]
}

async function main() {
    const TokenMRCH = await hre.ethers.getContractFactory("TokenMRCH");
    const tokenmrch = await TokenMRCH.deploy(
        process.env.MRCH_INITIALSUPPLY,
        process.env.MRCH_NAME,
        process.env.MRCH_SYMBOL
    );

    console.log(`TokenMRCH smart contract has been deployed to: ${tokenmrch.address}`);

    const TokenLP = await hre.ethers.getContractFactory("EmuTokenLP");
    const tokenlp = await TokenLP.deploy(
        process.env.LP_INITIALSUPPLY,
        process.env.LP_NAME,
        process.env.LP_SYMBOL
    );

    console.log(`TokenLP smart contract has been deployed to: ${tokenlp.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });