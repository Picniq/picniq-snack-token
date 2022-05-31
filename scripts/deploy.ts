// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

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
  const stake = await Stake.deploy(token.address, signers[0].address, 86400 * 7);
  
  await stake.deployed();

  let data = ethers.utils.solidityKeccak256(['uint256'], [1]);
  await token.connect(signers[0]).send(stake.address, ethers.utils.parseEther('5'), data);
  
  data = ethers.utils.solidityKeccak256(['uint256'], [2]);
  await token.connect(signers[1]).send(stake.address, ethers.utils.parseEther('1.0'), data);
  
  console.log(await stake.balanceOf(signers[1].address));
  console.log("Picniq Token deployed to:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
