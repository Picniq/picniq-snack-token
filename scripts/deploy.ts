// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { network, ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
import csv from "csv-parser";
import { keccak256 } from "ethers/lib/utils";
import fs from "fs";
import json from "../scripts/encoded.json";

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
    ethers.utils.parseEther('10000000'),
    signers[0].address,
    signers[1].address,
    "0xd30aa7828dbcad31659b8d89238fd3bb295937b880921ba163f8c1c3d6c2813c"
  );

  await token.deployed();

  const vest = await ethers.getContractAt('PicniqVesting', await token.vesting());
  const claim = await ethers.getContractAt('PicniqTokenClaim', await token.claim());

  let filename = __dirname + "/accounts.csv";
  const addresses = Object.keys(json);
  const values = Object.values(json);

  const list: {account: string, amount: string}[] = [];

  fs.createReadStream(filename)
  .pipe(csv())
  .on("data", (row: any) => {
      const user_dist = [row["account"], row["amount"]];
      const account = user_dist[0];
      const amount = user_dist[1];
      list.push({account, amount});
  }).on('end', async () => {
      // await ethers.provider.send('evm_increaseTime', [86400 * 30 * 12]);
      // await ethers.provider.send('evm_mine', []);
      fs.writeFile('amounts.json', JSON.stringify(list), () => {});
      for (let i=0; i < addresses.length; i++) {
          const address = addresses[i];
          await network.provider.request({
              method: 'hardhat_impersonateAccount',
              params: [address]
          });
          const signer = await ethers.getSigner(address);
          await network.provider.send("hardhat_setBalance", [
              address,
              "0x3130303030303030303030303030303030303030",
          ]);
          const amount = list.find((item: any) => item.account === address)?.amount ?? '0';
          if (amount !== '0') {
              await claim.connect(signer).claimAndVest(values[i].proof, ethers.utils.parseEther(amount), 12);
              console.log(signer.address, "balance:", ethers.utils.formatEther(await token.balanceOf(signer.address)));
          }
      }

      console.log('Total token supply:', ethers.utils.formatEther(await token.totalSupply()));
      console.log('Leftover in claim contract:', ethers.utils.formatEther(await claim.leftover()));
      console.log('Treasury holdings:', ethers.utils.formatEther(await token.balanceOf(signers[0].address)));
      console.log('Team holdings:', ethers.utils.formatEther(await token.balanceOf(signers[1].address)));
  })

  // const Stake = await ethers.getContractFactory("PicniqSingleStake");
  // const stake = await Stake.deploy(token.address, signers[0].address, 86400 * 7);
  
  // await stake.deployed();

  // let data = ethers.utils.solidityKeccak256(['uint256'], [1]);
  // await token.connect(signers[0]).send(stake.address, ethers.utils.parseEther('5'), data);
  
  // data = ethers.utils.solidityKeccak256(['uint256'], [2]);
  // await token.connect(signers[1]).send(stake.address, ethers.utils.parseEther('1.0'), data);
  
  // console.log(await stake.balanceOf(signers[1].address));
  // console.log("Picniq Token deployed to:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
