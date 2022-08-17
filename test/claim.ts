import { expect } from "chai";
import { ethers, network } from "hardhat";
import { MerkleTree } from "merkletreejs";
import csv from "csv-parser";
import { keccak256 } from "ethers/lib/utils";
import fs from "fs";
const json: any = require('../scripts/encoded.json');

describe("Claim", async function () {
    it("Should claim tokens on behalf of each account", async function () {
        const signers = await ethers.getSigners();

        // We get the contract to deploy
        const Token = await ethers.getContractFactory("PicniqToken");
        const token = await Token.deploy(
            ethers.utils.parseEther("10000000"),
            signers[0].address,
            signers[1].address,
            "0xd30aa7828dbcad31659b8d89238fd3bb295937b880921ba163f8c1c3d6c2813c"
        );

        await token.deployed();

        const vest = await ethers.getContractAt(
            "PicniqVesting",
            await token.vesting()
        );
        const claim = await ethers.getContractAt(
            "PicniqTokenClaim",
            await token.claim()
        );

        let filename = __dirname + "/accounts.csv";
        filename = filename.replace("test", "scripts");
        const addresses = Object.keys(json);
        const values: any = Object.values(json);

        const list: { account: string; amount: string }[] = [];

        fs.createReadStream(filename)
        .pipe(csv())
        .on("data", (row: any) => {
            const user_dist = [row["account"], row["amount"]];
            const account = user_dist[0];
            const amount = user_dist[1];
            list.push({ account, amount });
        })
        .on("end", async () => {
            await ethers.provider.send('evm_increaseTime', [86400 * 30 * 12]);
            await ethers.provider.send('evm_mine', []);

            // addresses.map(async (item: any) => {
            //     await network.provider.request({
            //         method: 'hardhat_impersonateAccount',
            //         params: [item]
            //     });

            //     const signer = await ethers.getSigner(item);

            //     await network.provider.send('hardhat_setBalance', [
            //         item,
            //         ['0x3130303030303030303030303030303030303030']
            //     ]);

            //     const amount = list.find((l: any) => l.account === item)?.amount ?? '0';
            //     const proof: any = json[item].proof;

            //     if (amount !== '0') {
            //         await claim.connect(signer).claimAndVest(proof, ethers.utils.parseEther(amount), 12);
            //         console.log(signer.address, 'balance:', ethers.utils.formatEther(await token.balanceOf(signer.address)));
            //     }
            // });

            for (let i = 0; i < addresses.length; i++) {
                const address = addresses[i];
                await network.provider.request({
                    method: "hardhat_impersonateAccount",
                    params: [address],
                });
                const signer = await ethers.getSigner(address);
                await network.provider.send("hardhat_setBalance", [
                    address,
                    "0x3130303030303030303030303030303030303030",
                ]);
                const amount =
                    list.find((item: any) => item.account === address)
                        ?.amount ?? "0";
                const proof = json[address].proof;

                if (amount !== "0") {
                    if (i % 2 === 1) {
                        await claim
                            .connect(signer)
                            .claimAndVest(
                                proof,
                                ethers.utils.parseEther(amount),
                                12
                            );                         
                    } else {
                        await claim.connect(signer).claimTokens(proof, ethers.utils.parseEther(amount));
                    }

                    console.log(
                        signer.address,
                        "balance:",
                        ethers.utils.formatEther(
                            await token.balanceOf(signer.address)
                        )
                    );
                }
            }
        });

        console.log("Supply:", await token.totalSupply());
        console.log("Leftover:", await claim.leftover());
    });
});