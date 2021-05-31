const hre = require("hardhat");
const dotenv = require('dotenv');
const network = hre.network.name;
const fs = require('fs');
const envConfig = dotenv.parse(fs.readFileSync(`.env-${network}`));
for (const k in envConfig) {
    process.env[k] = envConfig[k]
}

async function main() {
    //Deploy of staking smart contract
    const Staking = await hre.ethers.getContractFactory("Staking");
    const staking = await Staking.deploy(
        process.env.LPADDR,
        process.env.MRCHADDR
    );

    console.log(`Staking smart contract has been deployed to: ${staking.address}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });