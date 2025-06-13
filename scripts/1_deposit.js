const hre = require("hardhat");


SETTINGS = {};


async function main() {
    const deployer = (await hre.ethers.getSigners())[0];
    console.log(`Deployer: ${deployer.address}\nHYPE: ${await hre.ethers.provider.getBalance(deployer.address)}`);

    const xHYPE = await hre.ethers.getContractAt(
        "xHYPE",
        "0x9b823A30ee62108658f62bf248124223dE1B9aA6"
    );

    const tx = await xHYPE.deposit(
        {
            ...SETTINGS,
            value: hre.ethers.parseUnits("3.2", 18)
        }
    );
    const res = await tx.wait();
    console.log(`- deposit: ${res.hash}`);

    console.log(await xHYPE.internalPrice());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
