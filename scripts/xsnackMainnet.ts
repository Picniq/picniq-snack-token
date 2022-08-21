import { ethers } from "hardhat";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');
    const stake = '0xf43d2FA5a45AcD97177F680f5f84F9707be7eB11';

    const Compound = await ethers.getContractFactory('AutoCompoundingPicniqToken');
    const compound = await Compound.deploy(stake);

    await compound.deployed();

    console.log('xSNACK deployed to:', compound.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
