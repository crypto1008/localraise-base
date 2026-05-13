const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Balance:", ethers.formatEther(balance), "ETH");

  // Treasury = your own wallet for now
  const treasury = deployer.address;

  const LocalRaise = await ethers.getContractFactory("LocalRaise");
  const localraise = await LocalRaise.deploy(treasury);
  await localraise.waitForDeployment();

  const address = await localraise.getAddress();

  console.log("------------------------------------------");
  console.log("LocalRaise deployed to:", address);
  console.log("Treasury:", treasury);
  console.log("Basescan:", "https://basescan.org/address/" + address);
  console.log("------------------------------------------");
}

main().catch((e) => { console.error(e); process.exit(1); });
