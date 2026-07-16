const hre = require("hardhat");

async function main() {

    console.log("--------------------------------------");
    console.log("Deploying Smart Contracts...");
    console.log("--------------------------------------");

    // Deploy AccessControlManager

    const AccessControlManager =
        await hre.ethers.getContractFactory(
            "AccessControlManager"
        );

    const accessControl =
        await AccessControlManager.deploy();

    await accessControl.waitForDeployment();

    console.log(
        "AccessControlManager:",
        await accessControl.getAddress()
    );

    // Deploy PriorityManager

    const PriorityManager =
        await hre.ethers.getContractFactory(
            "PriorityManager"
        );

    const priorityManager =
        await PriorityManager.deploy();

    await priorityManager.waitForDeployment();

    console.log(
        "PriorityManager:",
        await priorityManager.getAddress()
    );

    // Deploy StorageProvider

    const StorageProvider =
        await hre.ethers.getContractFactory(
            "StorageProvider"
        );

    const storageProvider =
        await StorageProvider.deploy();

    await storageProvider.waitForDeployment();

    console.log(
        "StorageProvider:",
        await storageProvider.getAddress()
    );

    // Deploy HealthcareQoS

    const HealthcareQoS =
        await hre.ethers.getContractFactory(
            "HealthcareQoS"
        );

    const healthcare =
        await HealthcareQoS.deploy();

    await healthcare.waitForDeployment();

    console.log(
        "HealthcareQoS:",
        await healthcare.getAddress()
    );

    console.log("--------------------------------------");
    console.log("Deployment Successful");
    console.log("--------------------------------------");
}

main().catch((error) => {

    console.error(error);

    process.exitCode = 1;

});
