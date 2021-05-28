const { expect } = require("chai");
const web3 = require("web3");
const BigNumber = require("bignumber.js");
const { ethers } = require("hardhat");
const { providers } = require("web3");


describe("MRCH StakingV2 test", async () => {
    let tokenmrch;
    let tokenlp;
    let staking;
    let startTime = Math.floor(Date.now() / 1000);

    it("STEP 1. Creating MRCH token contract", async function () {
        const TokenMRCH = await hre.ethers.getContractFactory("TokenMRCH");
        tokenmrch = await TokenMRCH.deploy(
            process.env.MRCH_INITIALSUPPLY,
            process.env.MRCH_NAME,
            process.env.MRCH_SYMBOL
        );
    });

    it("STEP 2. Creating UNI-LP token contract", async function () {
        const TokenLP = await hre.ethers.getContractFactory("EmuTokenLP");
        tokenlp = await TokenLP.deploy(
            process.env.LP_INITIALSUPPLY,
            process.env.LP_NAME,
            process.env.LP_SYMBOL
        );
    });

    it("STEP 3. Creating Staking contract", async function () {
        const Staking = await hre.ethers.getContractFactory("StakingV2");
        staking = await Staking.deploy(
            tokenlp.address,
            tokenmrch.address
        );
    });

});