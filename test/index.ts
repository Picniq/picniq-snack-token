import { expect } from "chai";
import { ethers, network } from "hardhat";
import { MerkleTree } from "merkletreejs";
import csv from "csv-parser";
import { keccak256 } from "ethers/lib/utils";
import fs from "fs";
import json from "../scripts/encoded.json";

describe("Stake", async function () {
    it("Should...", async function () {
        const signers = await ethers.getSigners();

        // We get the contract to deploy
        const Token = await ethers.getContractFactory("PicniqToken");
        const token = await Token.deploy(
            ethers.utils.parseEther("25000000"),
            signers[0].address,
            signers[1].address,
            "0xd30aa7828dbcad31659b8d89238fd3bb295937b880921ba163f8c1c3d6c2813c"
        );

        await token.deployed();

        const Stake = await ethers.getContractFactory("PicniqSingleStake");
        const stake = await Stake.deploy(
            token.address,
            signers[0].address,
            86400 * 90
        );

        await stake.deployed();

        const ACStake = await ethers.getContractFactory(
            "AutoCompoundingPicniqToken"
        );
        const acStake = await ACStake.deploy(stake.address);

        console.log("Picniq Token deployed to:", token.address);
        console.log(
            `${await acStake.name()} (${await acStake.symbol()}) deployed to:`,
            acStake.address
        );

        await acStake.deployed();

        await token
            .connect(signers[0])
            .transfer(signers[2].address, ethers.utils.parseEther("1000"));
        await token
            .connect(signers[0])
            .approve(stake.address, ethers.constants.MaxUint256);
        await stake
            .connect(signers[0])
            .addRewardTokens(ethers.utils.parseEther("5000"));

        await token
            .connect(signers[1])
            .approve(acStake.address, ethers.constants.MaxUint256);
        await acStake
            .connect(signers[1])
            .deposit(ethers.utils.parseEther("1000"), signers[1].address);

        await token
            .connect(signers[2])
            .approve(acStake.address, ethers.constants.MaxUint256);
        await acStake
            .connect(signers[2])
            .deposit(ethers.utils.parseEther("1000"), signers[2].address);

        await ethers.provider.send("evm_increaseTime", [86400 * 30]);
        await ethers.provider.send("evm_mine", []);

        await acStake.harvest();

        await ethers.provider.send("evm_increaseTime", [86400 * 30]);
        await ethers.provider.send("evm_mine", []);

        await acStake.harvest();

        const shares = await acStake.balanceOf(signers[1].address);
        console.log(shares);
        console.log(await acStake.convertToAssets(shares));

        const assets = await acStake.convertToAssets(
            await acStake.balanceOf(signers[2].address)
        );
        await acStake
            .connect(signers[2])
            .withdraw(assets, signers[2].address, signers[2].address);
        await acStake
            .connect(signers[1])
            .redeem(
                await acStake.balanceOf(signers[1].address),
                signers[1].address,
                signers[1].address
            );
    });
});
