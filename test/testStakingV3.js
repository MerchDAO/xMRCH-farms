const { expect } = require("chai");
const web3 = require("web3");
const BigNumber = require("bignumber.js");
const { ethers } = require("hardhat");
const { providers } = require("web3");

describe("MRCH StakingV3 test", async () => {
    let tokenMRCH;
    let XMRCHToken;

    it("STEP 1. Creating MRCH token contract", async function () {
        const TokenMRCH = await hre.ethers.getContractFactory("TokenMRCH");
        tokenMRCH = await TokenMRCH.deploy(
            process.env.MRCH_INITIALSUPPLY,
            process.env.MRCH_NAME,
            process.env.MRCH_SYMBOL
        );
    });


});