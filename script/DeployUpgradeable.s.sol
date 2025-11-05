// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/IdentityRegistryUpgradeable.sol";
import "../contracts/ReputationRegistryUpgradeable.sol";
import "../contracts/ValidationRegistryUpgradeable.sol";
import "../contracts/ERC1967Proxy.sol";

contract DeployUpgradeableScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy IdentityRegistry implementation
        IdentityRegistryUpgradeable identityRegistryImpl = new IdentityRegistryUpgradeable();
        console.log("IdentityRegistry implementation deployed at:", address(identityRegistryImpl));

        // Deploy IdentityRegistry proxy
        bytes memory identityInitData = abi.encodeWithSelector(
            IdentityRegistryUpgradeable.initialize.selector
        );
        ERC1967Proxy identityProxy = new ERC1967Proxy(
            address(identityRegistryImpl),
            identityInitData
        );
        console.log("IdentityRegistry proxy deployed at:", address(identityProxy));

        // Deploy ReputationRegistry implementation
        ReputationRegistryUpgradeable reputationRegistryImpl = new ReputationRegistryUpgradeable();
        console.log("ReputationRegistry implementation deployed at:", address(reputationRegistryImpl));

        // Deploy ReputationRegistry proxy
        bytes memory reputationInitData = abi.encodeWithSelector(
            ReputationRegistryUpgradeable.initialize.selector,
            address(identityProxy)
        );
        ERC1967Proxy reputationProxy = new ERC1967Proxy(
            address(reputationRegistryImpl),
            reputationInitData
        );
        console.log("ReputationRegistry proxy deployed at:", address(reputationProxy));

        // Deploy ValidationRegistry implementation
        ValidationRegistryUpgradeable validationRegistryImpl = new ValidationRegistryUpgradeable();
        console.log("ValidationRegistry implementation deployed at:", address(validationRegistryImpl));

        // Deploy ValidationRegistry proxy
        bytes memory validationInitData = abi.encodeWithSelector(
            ValidationRegistryUpgradeable.initialize.selector,
            address(identityProxy)
        );
        ERC1967Proxy validationProxy = new ERC1967Proxy(
            address(validationRegistryImpl),
            validationInitData
        );
        console.log("ValidationRegistry proxy deployed at:", address(validationProxy));

        vm.stopBroadcast();

        // Save deployment addresses to a file
        string memory deploymentInfo = string(abi.encodePacked(
            "IdentityRegistry Proxy: ", vm.toString(address(identityProxy)), "\n",
            "IdentityRegistry Implementation: ", vm.toString(address(identityRegistryImpl)), "\n",
            "ReputationRegistry Proxy: ", vm.toString(address(reputationProxy)), "\n",
            "ReputationRegistry Implementation: ", vm.toString(address(reputationRegistryImpl)), "\n",
            "ValidationRegistry Proxy: ", vm.toString(address(validationProxy)), "\n",
            "ValidationRegistry Implementation: ", vm.toString(address(validationRegistryImpl)), "\n"
        ));

        console.log("\n=== Deployment Summary ===");
        console.log(deploymentInfo);
    }
}
