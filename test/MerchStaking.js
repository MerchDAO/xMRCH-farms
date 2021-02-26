const { expect } = require("chai");
const { ethers } = require("hardhat");
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
  });
});
