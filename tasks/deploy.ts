import { task } from "hardhat/config";
import fs from "fs";

task("Deploy:Arbitrum", "Deploys the project").setAction(
  async (_, hre): Promise<null> => {
    const deployment = require("../deployments/deployments.json");

    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;

    const handler = deployment[chainId].handler;
    const feeToken = deployment[chainId].feeToken;

    const Contract = await hre.ethers.getContractFactory("VetMe");

    const contract = await hre.upgrades.deployProxy(Contract, [
      handler,
      feeToken,
    ]);
    await contract.deployed();
    console.log(`contract deployed to: `, contract.address);

    deployment[chainId].contract = contract.address;

    fs.writeFileSync(
      "deployments/deployments.json",
      JSON.stringify(deployment)
    );

    return null;
  }
);

task("Deploy:Ethereum", "Deploys the project").setAction(
  async (_, hre): Promise<null> => {
    const deployment = require("../deployments/deployments.json");

    const network = await hre.ethers.provider.getNetwork();
    const chainId = network.chainId;

    const handler = deployment[chainId].handler;
    const feeToken = deployment[chainId].feeToken;

    const Contract = await hre.ethers.getContractFactory("VetMeEthAdapter");

    const contract = await hre.upgrades.deployProxy(Contract, [
      handler,
      feeToken,
    ]);
    await contract.deployed();
    console.log(`contract deployed to: `, contract.address);

    deployment[chainId].contract = contract.address;

    fs.writeFileSync(
      "deployments/deployments.json",
      JSON.stringify(deployment)
    );

    return null;
  }
);
