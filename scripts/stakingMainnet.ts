import { ethers } from "hardhat";

async function main() {
    // Hardhat always runs the compile task when running scripts with its command
    // line interface.
    //
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');
    const token = '0x';
    const dist = '0x';

    const Stake = await ethers.getContractFactory('PicniqSingleStake');
    const stake = await Stake.deploy(token, dist, 86400 * 365);

    await stake.deployed();

    console.log('Staking deployed to:', stake.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
