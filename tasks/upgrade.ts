import { task } from "hardhat/config";

task("Upgrade:ETH").setAction(async function (_, hre) {
  const deployment = require("../deployments/deployments.json");

  const network = await hre.ethers.provider.getNetwork();
  const chainId = network.chainId;

  const contract = deployment[chainId].contract;
  const contractName = "VetMeEthAdapter";

  console.log("Contract Upgrade Started ");
  const C1 = await hre.ethers.getContractFactory(contractName);
  const tx = await hre.upgrades.upgradeProxy(contract, C1);
  // console.log(tx);
  console.log(contractName + " Proxy Contract upgraded to " + contract);
  const implementationAddr =
    await hre.upgrades.erc1967.getImplementationAddress(contract);
  console.log(
    contractName + " Implementation Contract deployed to: ",
    implementationAddr
  );
  //   console.log("Contract Upgrade Ended");

  //   console.log(" Storage Update Started");
  //   deployments[network][contractName].implementation.push(implementationAddr);
  //   deployments[network][contractName].updatedTime.push(Date.now());
  //   fs.writeFileSync(
  //     "./deployment/deployments.json",
  //     JSON.stringify(deployments)
  //   );
  //   console.log(" Storage Update Ended ");
  //   console.log(proxyAddr, "-", implementationAddr);
});

task("Upgrade:ARB").setAction(async function (_, hre) {
  const deployment = require("../deployments/deployments.json");

  const network = await hre.ethers.provider.getNetwork();
  const chainId = network.chainId;

  const contract = deployment[chainId].contract;
  const contractName = "VetMe";

  console.log("Contract Upgrade Started ");
  const C1 = await hre.ethers.getContractFactory(contractName);
  const tx = await hre.upgrades.upgradeProxy(contract, C1);
  // console.log(tx);
  console.log(contractName + " Proxy Contract upgraded to " + contract);
  const implementationAddr =
    await hre.upgrades.erc1967.getImplementationAddress(contract);
  console.log(
    contractName + " Implementation Contract deployed to: ",
    implementationAddr
  );
  //   console.log("Contract Upgrade Ended");

  //   console.log(" Storage Update Started");
  //   deployments[network][contractName].implementation.push(implementationAddr);
  //   deployments[network][contractName].updatedTime.push(Date.now());
  //   fs.writeFileSync(
  //     "./deployment/deployments.json",
  //     JSON.stringify(deployments)
  //   );
  //   console.log(" Storage Update Ended ");
  //   console.log(proxyAddr, "-", implementationAddr);
});
