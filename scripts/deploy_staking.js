// npx hardhat run --network rinkeby scripts/deploy_staking.js
// npx hardhat verify --network rinkeby 0x1fDeDe73120b4Ffa32407Ae0670a4478e659B218 "0x4d3524ec76fBeD794d813dec53fbD6DC9509AfFf" "0x0dD0A829bf99baa3A880191Db5B0e84b0be4fd75"

const hre = require("hardhat");
const dotenv = require('dotenv');
const network = hre.network.name;
const fs = require('fs');
const envConfig = dotenv.parse(fs.readFileSync(`.env`));
for (const k in envConfig) {
    process.env[k] = envConfig[k]
}

async function main() {
    //Deploy of staking smart contract
    const Staking = await hre.ethers.getContractFactory("StakingV2");
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