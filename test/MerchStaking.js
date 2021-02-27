const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("./utilities")

const {
  isCallTrace,
} = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

describe("MerchStaking contract", function () {
  let MerchStaking;
  let merchStaking;
  let owner;
  let addr1;
  let addr2;
  let minter;
  let addrs;
  let ERC20Mock;
  let stakeToken;
  let rewardToken;

  beforeEach(async function () {
    MerchStaking = await ethers.getContractFactory("MerchStaking");
    [
      owner, 
      addr1,
      addr2,
      minter,
      ...addrs
    ] = await ethers.getSigners();
    ERC20Mock = await ethers.getContractFactory("ERC20Mock", minter)
    stakeToken = await ERC20Mock.deploy("LPToken", "LP", "10000000")
    rewardToken = await ERC20Mock.deploy("MerchDAO", "MRCH", "10000000000")
    merchStaking = await MerchStaking.deploy(stakeToken.address, rewardToken.address);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await merchStaking.owner()).to.equal(owner.address);
    });

    it("Should set correct state variables", async function () {
        expect(await merchStaking.stakeToken()).to.equal(stakeToken.address);
        expect(await merchStaking.rewardToken()).to.equal(rewardToken.address);
    });

  });

  describe("MerchStaking", function () {
    it("Should stake token to the pool", async function () {
        await rewardToken.transfer(merchStaking.address, 100000000);
        expect(await rewardToken.balanceOf(merchStaking.address)).to.equal(100000000);
        const currentTimeStamp = Math.floor(Date.now() / 1000);
        const startTime = currentTimeStamp;
        const endTime = startTime + 30 * 24 * 60 * 60; 
        await merchStaking.addPool(100000000, 5*10**12, startTime, endTime, 10*10**12, false);

        await stakeToken.transfer(addr1.address, "10000");
        await stakeToken.connect(addr1).approve(merchStaking.address, "10000", { from: addr1.address });
        await merchStaking.connect(addr1).stake(0, 1000);
        expect(await stakeToken.balanceOf(addr1.address)).to.equal(9000);
        expect((await merchStaking.stakes(0, addr1.address)).equivalentAmount).to.equal(10000);
        await time.advanceBlockTo("7000");
        await merchStaking.connect(addr1).claim(0);
        expect(await rewardToken.balanceOf(addr1.address)).to.equal(1);
        await time.advanceBlockTo("14000");
        await merchStaking.connect(addr1).claim(0);
        expect(await rewardToken.balanceOf(addr1.address)).to.equal(2);
        await merchStaking.connect(addr1).withdraw(0);
        expect(await rewardToken.balanceOf(addr1.address)).to.equal(2);
        expect(await stakeToken.balanceOf(addr1.address)).to.equal(10000);

    });
  });
});



