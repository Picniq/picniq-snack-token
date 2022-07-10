import { expect } from "chai";
import { network, ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
import csv from "csv-parser";
import { keccak256 } from "ethers/lib/utils";
import fs from "fs";
import json from "../scripts/encoded.json";

describe("Claim tokens", function () {
    it("Should claim tokens on behalf of each account", async function () {
        const signers = await ethers.getSigners();

        // We get the contract to deploy
        const Token = await ethers.getContractFactory("PicniqToken");
        const token = await Token.deploy(
          ethers.utils.parseEther('25000000'),
          signers[0].address,
          signers[1].address,
          "0xd30aa7828dbcad31659b8d89238fd3bb295937b880921ba163f8c1c3d6c2813c"
        );
      
        await token.deployed();

        let filename = __dirname + "/accounts.csv";
        filename = filename.replace("test", "scripts");
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
                for (let i=0; i < addresses.length; i++) {
                    const address = addresses[i];
                    await network.provider.request({
                        method: 'hardhat_impersonateAccount',
                        params: [address]
                    });
                    // await network.provider.send('evm_increaseTime', [17280000]);
                    // await network.provider.send('evm_mine', []);
                    const signer = await ethers.getSigner(address);
                    await network.provider.send("hardhat_setBalance", [
                        address,
                        "0x3130303030303030303030303030303030303030",
                    ]);
                    const amount = list.find((item: any) => item.account === address)?.amount ?? '0';
                    if (amount !== '0') {
                        await token.connect(signer).claimTokens(values[i].proof, ethers.utils.parseEther(amount));
                        console.log(signer.address, await token.balanceOf(signer.address));
                    }
                }
    
                console.log(await token.totalSupply());
            })
    });
});

