const hre = require("hardhat");


SETTINGS = {};


async function main() {
    const deployer = (await hre.ethers.getSigners())[0];
    console.log(`Deployer: ${deployer.address}\nHYPE: ${await hre.ethers.provider.getBalance(deployer.address)}`);

    const xHYPE = await hre.ethers.deployContract(
        "xHYPE",
        [
            deployer.address,
            "0xef22f260eec3b7d1edebe53359f5ca584c18d5ac",
            1000
        ],
        SETTINGS
    );
    await xHYPE.waitForDeployment();
    console.log(`- xHYPE: ${await xHYPE.getAddress()}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});


// - xHYPE: 0x9b823A30ee62108658f62bf248124223dE1B9aA6
