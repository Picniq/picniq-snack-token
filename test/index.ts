import { expect } from "chai";
import { ethers } from "hardhat";

describe("Stake", function () {
  it("Should...", async function () {
    const signers = await ethers.getSigners();

    // We get the contract to deploy
    const Token = await ethers.getContractFactory("PicniqToken");
    const token = await Token.deploy(
      ethers.utils.parseEther('25000000'),
      signers[0].address,
      signers[1].address,
      [],
      "0xd30aa7828dbcad31659b8d89238fd3bb295937b880921ba163f8c1c3d6c2813c"
    );
  
    await token.deployed();
  
    const Stake = await ethers.getContractFactory("PicniqSingleStake");
    const stake = await Stake.deploy(token.address, signers[0].address, 86400 * 90);
    
    await stake.deployed();

    const ACStake = await ethers.getContractFactory("AutoCompoundingPicniqToken");
    const acStake = await ACStake.deploy(stake.address, []);

    await acStake.deployed();
  
    let data = ethers.utils.solidityKeccak256(['uint256'], [1]);
    await token.connect(signers[0]).send(stake.address, ethers.utils.parseEther('5000'), data);

    await token.connect(signers[1]).send(acStake.address, ethers.utils.parseEther('1000'), []);

    await ethers.provider.send("evm_increaseTime", [86400 * 30]);
    await ethers.provider.send("evm_mine", []);

    await acStake.harvest();

    await ethers.provider.send("evm_increaseTime", [86400 * 30]);
    await ethers.provider.send("evm_mine", []);

    await acStake.harvest();
    
    // data = ethers.utils.solidityKeccak256(['uint256'], [2]);
    // await token.connect(signers[1]).send(stake.address, ethers.utils.parseEther('1000'), data);
    
    // console.log(await stake.balanceOf(signers[1].address));
    console.log("Picniq Token deployed to:", token.address);
    console.log(`${await acStake.name()} (${await acStake.symbol()}) deployed to:`, acStake.address);

    const assets = await acStake.convertToAssets(await acStake.balanceOf(signers[1].address));

    // await acStake.connect(signers[1]).redeem(await acStake.balanceOf(signers[1].address), signers[1].address, signers[1].address);
    console.log(await token.balanceOf(signers[1].address));
    console.log(await stake.balanceOf(acStake.address));
    await acStake.connect(signers[1]).withdraw(assets, signers[1].address, signers[1].address);
    await token.approve(acStake.address, ethers.constants.MaxUint256);
    console.log(await token.balanceOf(signers[1].address));
    console.log(await stake.balanceOf(acStake.address));
    await acStake.connect(signers[0]).mint(ethers.utils.parseEther('500'), signers[0].address);

    console.log(await token.balanceOf(signers[0].address));
    console.log(await stake.balanceOf(acStake.address));
    await acStake.connect(signers[0]).redeem(ethers.utils.parseEther('500'), signers[0].address, signers[0].address);
    console.log(await token.balanceOf(signers[0].address));
    console.log(await stake.balanceOf(acStake.address));
    console.log(await token.balanceOf(acStake.address));
    // await stake.connect(signers[1]).exit();
    
    // console.log(await token.balanceOf(stake.address));

    // await stake.connect(signers[0]).withdrawRewardTokens();

    // console.log(await token.balanceOf(stake.address));
  });
});
