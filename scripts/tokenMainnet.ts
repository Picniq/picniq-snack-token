import { ethers } from "hardhat";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');
    const treasury = '0x';
    const team = '0x';

    const Token = await ethers.getContractFactory('PicniqToken');
    const token = await Token.deploy(
        ethers.utils.parseEther('10000000'),
        treasury,
        team,
        "0xd30aa7828dbcad31659b8d89238fd3bb295937b880921ba163f8c1c3d6c2813c"
      );

    await token.deployed();

    console.log('Picniq token deployed to:', token.address);
    console.log('Claim contract deployed to:', await token.claim());
    console.log('Vesting contract deployted to:', await token.vesting());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
