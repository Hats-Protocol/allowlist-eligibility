import { config as dotEnvConfig } from "dotenv";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet, Contract } from "zksync-ethers";
import * as hre from "hardhat";

const AllowlistEligibilityFactory = require("../artifacts-zk/src/AllowlistEligibilityFactory.sol/AllowlistEligibilityFactory.json");

// Before executing a real deployment, be sure to set these values as appropriate for the environment being deployed
// to. The values used in the script at the time of deployment can be checked in along with the deployment artifacts
// produced by running the scripts.
const contractName = "AllowlistEligibility";
const HATS_ID = 1;
const HATS = "0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e";
const SALT_NONCE = 1;
const FACTORY_ADDRESS = "0xA29Ae9e5147F2D1211F23D323e4b2F3055E984B0";
const initData = "0x000000000000000000000000a3dabd368bae702199959e55560f688c213fbb3c000000000000000000000000eac5f0d4a9a45e1f9fdd0e7e2882e9f60e301156"; // Example data

async function main() {
  dotEnvConfig();

  const deployerPrivateKey = process.env.PRIVATE_KEY;
  if (!deployerPrivateKey) {
    throw "Please set PRIVATE_KEY in your .env file";
  }

  console.log("Deploying " + contractName + "...");

  const zkWallet = new Wallet(deployerPrivateKey);
  const deployer = new Deployer(hre, zkWallet);
  const allowlistEligibilityFactory = new Contract(
    FACTORY_ADDRESS,
    AllowlistEligibilityFactory.abi,
    deployer.zkWallet
  );

  const tx = await allowlistEligibilityFactory.deployModule(
    HATS_ID,
    HATS,
    initData,
    SALT_NONCE
  );
  const tr = await tx.wait();
  console.log("Allowlist eligibility deployed at " + tr.contractAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
