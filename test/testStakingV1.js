const { expect } = require("chai");
const web3 = require("web3");
const BigNumber = require("bignumber.js");
const { ethers } = require("hardhat");
const { providers } = require("web3");


describe("MRCH StakingV1 test", async () => {
    let tokenmrch;
    let tokenxmrch;
    let staking;
    let startTime = Math.floor(Date.now() / 1000);
    let distriburionTime = 1000;
    let halvingTime = 5000;
    let fineTime = distriburionTime;
    let finePercent = 200000;
    let finePrecision = 1000000;

    it("STEP 1. Creating Staking contract", async function () {
        const Staking = await hre.ethers.getContractFactory("StakingV1");
        staking = await Staking.deploy(
            ethers.utils.parseEther("100.0"), //process.env.REWARDTOTAL,
            startTime,//process.env.STAKINGSTART,
            distriburionTime,//process.env.DISTRIBUTIONTIME,
            halvingTime,//process.env.HALVINGTIME
            fineTime,
            finePercent,
            finePrecision
        );
    });

    it("STEP 2. Creating MRCH token contract", async function () {
        const TokenMRCH = await hre.ethers.getContractFactory("TokenMRCH");
        tokenmrch = await TokenMRCH.deploy(
            process.env.MRCH_INITIALSUPPLY,
            process.env.MRCH_NAME,
            process.env.MRCH_SYMBOL
        );
    });

    it("STEP 3. Creating XRMCH token contract", async function () {
        const XMRCH = await hre.ethers.getContractFactory("XMRCH");
        const tokenxmrch = await XMRCH.deploy(
            process.env.INIT_ADDRESS
        );

        staking.initialize(tokenmrch.address, tokenxmrch.address);
    });

    it("STEP 4. Minting", async function () {
        const [...addr] = await ethers.getSigners();
        tokenxmrch.mint(ethers.utils.parseEther("100000.0"));
        tokenxmrch.transfer(staking.address, ethers.utils.parseEther("10000.0"));
    });

    it("STEP 5. Staking", async function () {
        const [...addr] = await ethers.getSigners();

        let info = await staking.getUserInfoByAddress(addr[0].address);
        console.log("Available rewards:", info[1] / 1e18);
        console.log("Epoch Round:", (await staking.epochRound()).toString());

        // staking
        await tokenmrch.approve(staking.address, ethers.utils.parseEther("1000.0"));
        await staking.stake(ethers.utils.parseEther("30.0"));

        info = await staking.getUserInfoByAddress(addr[0].address);

        console.log("TPS:", (await staking.tokensPerStake()) / 1e18);

        ethers.provider.send("evm_setNextBlockTimestamp", [startTime + 999]);
        ethers.provider.send("evm_mine");

        info = await staking.getUserInfoByAddress(addr[0].address);

        // staking again
        await staking.stake(ethers.utils.parseEther("5.0"));
        await staking.update();

        info = await staking.getUserInfoByAddress(addr[0].address);

        ethers.provider.send("evm_setNextBlockTimestamp", [startTime + 1700]);
        ethers.provider.send("evm_mine");

        await staking.update();

        info = await staking.getUserInfoByAddress(addr[0].address);
        console.log("TPS:", (await staking.tokensPerStake()) / 1e18);
        console.log("Epoch TPS", (await staking.epochTPS()) / 1e18);

        info = await staking.getUserInfoByAddress(addr[0].address);
        console.log("Available rewards:", info[1] / 1e18);

        // unstaking
        staking.unstake(ethers.utils.parseEther("35.0"));

        info = await staking.getUserInfoByAddress(addr[0].address);
        console.log("Amount staked:", info[0] / 1e18);
        console.log("Available rewards:", info[1] / 1e18);

        let balance = await tokenmrch.balanceOf(addr[0].address);
        // console.log(balance / 1e18);

        // claiming
        await staking.claim();

        balance = await tokenxmrch.balanceOf(addr[0].address);
        // console.log(balance / 1e18);

        // staking againg
        await staking.stake(ethers.utils.parseEther("5.0"));

        ethers.provider.send("evm_setNextBlockTimestamp", [startTime + 1999]);
        ethers.provider.send("evm_mine");

        await staking.update();

        console.log("Epoch Round:", (await staking.epochRound()).toString());
        console.log("TPS:", (await staking.tokensPerStake()) / 1e18);
        console.log("Epoch TPS", (await staking.epochTPS()) / 1e18);

        await staking.unstake(ethers.utils.parseEther("5.0"));

        info = await staking.getUserInfoByAddress(addr[0].address);
        console.log("Amount staked:", info[0] / 1e18);
        console.log("Available rewards:", info[1] / 1e18);
        // console.log(ethers.utils.parseEther("5.0") - info[0]);
    });



    it("STEP 6. Unstaking", async function () {
        const [...addr] = await ethers.getSigners();

        let balanceBefore = await tokenmrch.balanceOf(addr[0].address);
        console.log(balanceBefore.toString());

        await staking.stake(ethers.utils.parseEther("25.0"));
        await staking.unstake(ethers.utils.parseEther("20.0"));

        let balanceAfter = await tokenmrch.balanceOf(addr[0].address);
        console.log(balanceAfter.toString());

        console.log(parseInt(balanceBefore)-parseInt(balanceAfter));

        ethers.provider.send("evm_setNextBlockTimestamp", [startTime + 4000]);
        ethers.provider.send("evm_mine");

        await staking.stake(ethers.utils.parseEther("150.0"));
        await staking.unstake(ethers.utils.parseEther("50.0"));

        balanceAfter = await tokenmrch.balanceOf(addr[0].address);
        console.log(balanceAfter.toString());

        await staking.unstake(ethers.utils.parseEther("105.0"));

        balanceAfter = await tokenmrch.balanceOf(addr[0].address);
        console.log(balanceAfter.toString());

        let balance = await tokenmrch.balanceOf(staking.address);
        console.log(balance.toString());
    });

});