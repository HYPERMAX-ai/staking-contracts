const hre = require("hardhat");


SETTINGS = {};


async function main() {
    const deployer = (await hre.ethers.getSigners())[0];
    console.log(`Deployer: ${deployer.address}\nHYPE: ${await hre.ethers.provider.getBalance(deployer.address)}`);

    const xHYPE = await hre.ethers.getContractAt(
        "xHYPE",
        "0x9b823A30ee62108658f62bf248124223dE1B9aA6"
    );

    console.log(await xHYPE.pendings(
        deployer.address
    ));
    console.log(`- before balance: ${await hre.ethers.provider.getBalance(await xHYPE.getAddress())}`);
    console.log(`- before balance: ${await hre.ethers.provider.getBalance(deployer.address)}`);
    // process.exit(1);

    const tx = await xHYPE.withdrawFinalize(
        deployer.address,
        { ...SETTINGS }
    );
    const res = await tx.wait();
    console.log(`- withdrawFinalize: ${res.hash}`);

    console.log(await xHYPE.internalPrice());

    console.log(`- after balance: ${await hre.ethers.provider.getBalance(await xHYPE.getAddress())}`);
    console.log(`- after balance: ${await hre.ethers.provider.getBalance(deployer.address)}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
