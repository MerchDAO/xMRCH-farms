const hre = require("hardhat");
const dotenv = require('dotenv');
const network = hre.network.name;
const fs = require('fs');
const envConfig = dotenv.parse(fs.readFileSync(`.env`));
for (const k in envConfig) {
    process.env[k] = envConfig[k]
}

async function main() {
    const XMRCH = await hre.ethers.getContractFactory("XMRCH");
    const tokenxmrch = await XMRCH.deploy(
        process.env.INIT_ADDRESS
    );

    console.log(`XMRCH token smart contract has been deployed to: ${tokenxmrch.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });