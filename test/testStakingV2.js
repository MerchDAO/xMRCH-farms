const { expect } = require("chai");
const web3 = require("web3");
const BigNumber = require("bignumber.js");
const { ethers } = require("hardhat");
const { providers } = require("web3");


describe("MRCH StakingV2 test", async () => {
    let tokenmrch;
    let tokenlp;
    let staking;
    let startTime = Math.floor(Date.now() / 1000) + 15;
    console.log("data", Math.floor(Date.now() / 1000));
    console.log("startTime", startTime);
    let endTime = startTime + 1000;
    console.log("endTime", endTime);
    let freezeTime = 100;
    let percent = 5;
    console.log("freezeTime", freezeTime);

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

    it("STEP 4. Minting", async function () {
        const [...addr] = await ethers.getSigners();
        tokenlp.Mint(ethers.utils.parseEther("100000.0"));
        tokenlp.transfer(addr[1].address, ethers.utils.parseEther("100.0"));
        tokenlp.transfer(addr[2].address, ethers.utils.parseEther("100.0"));
        tokenlp.transfer(addr[3].address, ethers.utils.parseEther("100.0"));
    });

    it("STEP 5. Add pool", async function () {
        const [...addr] = await ethers.getSigners();

        let balance = await tokenmrch.balanceOf(addr[0].address);
        console.log('balance', balance / 1e18);

        await tokenmrch.approve(staking.address, ethers.utils.parseEther("1000.0"));

        let allowance = await tokenmrch.allowance(addr[0].address, staking.address);
        console.log('allowance', allowance / 1e18);

        let check = await staking.getTimeStamp();
        console.log('check2', check.toString());

        staking.addPool(ethers.utils.parseEther("1000.0"), startTime, endTime, freezeTime, percent);
    });

    it("STEP 6. Staking", async function () {
        const [...addr] = await ethers.getSigners();

    });

    it("STEP 7. Unstaking", async function () {
        const [...addr] = await ethers.getSigners();

    });


});