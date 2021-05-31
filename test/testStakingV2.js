const { expect } = require("chai");
const web3 = require("web3");
const BigNumber = require("bignumber.js");
const { ethers } = require("hardhat");
const { providers } = require("web3");

describe("MRCH StakingV2 test", async () => {
    let tokenmrch;
    let tokenlp;
    let staking;
    let startTime;
    let endTime;
    let freezeTime = 100;
    let percent = 5;

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

        let timeStamp = await staking.getTimeStamp();
        console.log('TimeStamp: Add pool', timeStamp.toString());

        startTime = +timeStamp + 3;
        console.log("startTime", startTime);

        endTime = +startTime + 1000;
        console.log("endTime", endTime);

        let balance = await tokenmrch.balanceOf(addr[0].address);
        console.log('balance', balance / 1e18);

        await tokenmrch.approve(staking.address, ethers.utils.parseEther("1000.0"));

        let allowance = await tokenmrch.allowance(addr[0].address, staking.address);
        console.log('allowance', allowance / 1e18);

        staking.addPool(ethers.utils.parseEther("1000.0"), startTime, endTime, freezeTime, percent);
    });

    it("STEP 6. Staking", async function () {
        const [...addr] = await ethers.getSigners();

        await tokenlp.connect(addr[1]).approve(staking.address, ethers.utils.parseEther("5.0"));

        let allowance = await tokenlp.allowance(addr[1].address, staking.address);
        console.log('allowance', allowance / 1e18);

        await tokenlp.connect(addr[2]).approve(staking.address, ethers.utils.parseEther("5.0"));

        allowance = await tokenlp.allowance(addr[2].address, staking.address);
        console.log('allowance', allowance / 1e18);

        await tokenlp.connect(addr[3]).approve(staking.address, ethers.utils.parseEther("5.0"));

        allowance = await tokenlp.allowance(addr[3].address, staking.address);
        console.log('allowance', allowance / 1e18);

        let timeStamp = await staking.getTimeStamp();
        console.log('TimeStamp: Staking', timeStamp.toString());

        await staking.connect(addr[1]).stake(0, ethers.utils.parseEther("5.0"));
        await staking.connect(addr[2]).stake(0, ethers.utils.parseEther("5.0"));
        await staking.connect(addr[3]).stake(0, ethers.utils.parseEther("5.0"));

        expect(await tokenlp.balanceOf(staking.address)).to.equal(ethers.utils.parseEther("15.0"));
    });

    it("STEP 7. Unstaking", async function () {
        const [...addr] = await ethers.getSigners();

        expect(await tokenmrch.balanceOf(addr[1].address)).to.equal(ethers.utils.parseEther("0.0"));
        expect(await tokenmrch.balanceOf(addr[2].address)).to.equal(ethers.utils.parseEther("0.0"));
        expect(await tokenmrch.balanceOf(addr[3].address)).to.equal(ethers.utils.parseEther("0.0"));

        ethers.provider.send("evm_setNextBlockTimestamp", [endTime + 1]);
        ethers.provider.send("evm_mine");

        await staking.connect(addr[1]).withdraw(0);
        expect(await tokenlp.balanceOf(addr[1].address)).to.equal(ethers.utils.parseEther("100.0"));

        await staking.connect(addr[2]).withdraw(0);
        expect(await tokenlp.balanceOf(addr[2].address)).to.equal(ethers.utils.parseEther("100.0"));

        await staking.connect(addr[3]).withdraw(0);
        expect(await tokenlp.balanceOf(addr[3].address)).to.equal(ethers.utils.parseEther("100.0"));

        expect(await tokenlp.balanceOf(staking.address)).to.equal(ethers.utils.parseEther("0"));

        expect(await tokenmrch.balanceOf(addr[1].address)).to.equal('333668005354752342704');
        expect(await tokenmrch.balanceOf(addr[2].address)).to.equal('333333333333333333333');
        expect(await tokenmrch.balanceOf(addr[3].address)).to.equal('332998661311914323962');
    });
});