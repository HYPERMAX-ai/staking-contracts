const hre = require("hardhat");


SETTINGS = {};


async function main() {
    const deployer = (await hre.ethers.getSigners())[0];
    console.log(`Deployer: ${deployer.address}\nHYPE: ${await hre.ethers.provider.getBalance(deployer.address)}`);

    const xHYPE = await hre.ethers.getContractAt(
        "xHYPE",
        "0x9b823A30ee62108658f62bf248124223dE1B9aA6"
    );

    {
        const xHYPE20 = await hre.ethers.getContractAt(
            "ERC20",
            await xHYPE.getAddress()
        );
        console.log(`- balanceOf: ${await xHYPE20.balanceOf(deployer.address)}`);
    }
    // process.exit(1);

    const tx = await xHYPE.withdrawRequest(
        hre.ethers.parseUnits("3.0", 18),
        { ...SETTINGS }
    );
    const res = await tx.wait();
    console.log(`- withdrawRequest: ${res.hash}`);

    console.log(await xHYPE.internalPrice());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
