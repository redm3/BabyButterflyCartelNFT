const hre = require("hardhat");

async function main() {

  const BabyButterflyCartelNFT = await hre.ethers.getContractFactory("BabyButterflyCartelNFT");
  const babyButterflyCartelNFT = await BabyButterflyCartelNFT.deploy(10000,"0x4bc4bba990fe31d529d987f7b8ccf79f1626e559");

  await babyButterflyCartelNFT.deployed(10000,"0x4bc4bba990fe31d529d987f7b8ccf79f1626e559");

  console.log("BabyButterflyCartelNFT deployed to:", babyButterflyCartelNFT.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
