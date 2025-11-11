import hre from "hardhat";
import { encodeAbiParameters, getContract } from "viem";
import { taikoHoodi } from "./taiko-hoodi.js";

async function readArtifact(name: string) {
    return await hre.artifacts.readArtifact(name);
}

async function deployWithViem(walletClient: any, publicClient: any, name: string, args: any[] = []) {
    const artifact = await readArtifact(name);
    // @ts-ignore
    const res = await walletClient.deployContract({ abi: artifact.abi, bytecode: artifact.bytecode as `0x${string}`, args });
    const txHash = (res as any).hash || (res as any).request?.hash || (res as any).request?.txHash || res;
    const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    if (!receipt.contractAddress) throw new Error("deployment failed: no contract address in receipt");
    return { address: receipt.contractAddress, receipt };
}

async function getViemContract(abi: any, address: `0x${string}`, publicClient: any, walletClient?: any) {
    // Cast to any to avoid type mismatches in this repo's viem/hardhat types
    return (getContract as any)({ abi, address, publicClient, walletClient });
}

async function main() {
    const { viem } = await hre.network.connect();
    const publicClient = await viem.getPublicClient({ chain: taikoHoodi });
    const [walletClient] = await viem.getWalletClients({ chain: taikoHoodi });

    console.log("Deploying ERC-8004 Upgradeable Contracts to Taiko Hoodi");
    console.log("===================================================");
    console.log("Deployer address:", walletClient.account.address);

    // Identity implementation
    const identityImpl = await deployWithViem(walletClient, publicClient, "IdentityRegistryUpgradeable");
    console.log("Identity implementation:", identityImpl.address);

    // Identity proxy
    const identityInit = "0x8129fc1c" as `0x${string}`;
    const identityProxy = await deployWithViem(walletClient, publicClient, "ERC1967Proxy", [identityImpl.address, identityInit]);
    console.log("Identity proxy:", identityProxy.address);

    // Bind identity contract
    const identityArtifact = await readArtifact("IdentityRegistryUpgradeable");
    const identityRegistry = await getViemContract(identityArtifact.abi, identityProxy.address as `0x${string}`, publicClient, walletClient);

    // Reputation implementation & proxy
    const reputationImpl = await deployWithViem(walletClient, publicClient, "ReputationRegistryUpgradeable");
    console.log("Reputation implementation:", reputationImpl.address);
    const reputationInitCalldata = encodeAbiParameters([{ name: "identityRegistry", type: "address" }], [identityProxy.address]);
    const reputationInitData = ("0xc4d66de8" + reputationInitCalldata.slice(2)) as `0x${string}`;
    const reputationProxy = await deployWithViem(walletClient, publicClient, "ERC1967Proxy", [reputationImpl.address, reputationInitData]);
    console.log("Reputation proxy:", reputationProxy.address);
    const reputationArtifact = await readArtifact("ReputationRegistryUpgradeable");
    const reputationRegistry = await getViemContract(reputationArtifact.abi, reputationProxy.address as `0x${string}`, publicClient, walletClient);

    // Validation implementation & proxy
    const validationImpl = await deployWithViem(walletClient, publicClient, "ValidationRegistryUpgradeable");
    console.log("Validation implementation:", validationImpl.address);
    const validationInitCalldata = encodeAbiParameters([{ name: "identityRegistry", type: "address" }], [identityProxy.address]);
    const validationInitData = ("0xc4d66de8" + validationInitCalldata.slice(2)) as `0x${string}`;
    const validationProxy = await deployWithViem(walletClient, publicClient, "ERC1967Proxy", [validationImpl.address, validationInitData]);
    console.log("Validation proxy:", validationProxy.address);
    const validationArtifact = await readArtifact("ValidationRegistryUpgradeable");
    const validationRegistry = await getViemContract(validationArtifact.abi, validationProxy.address as `0x${string}`, publicClient, walletClient);

    // Verify via read calls
    // Use publicClient.readContract directly to avoid relying on contract wrappers
    const identityVersion = await publicClient.readContract({
        address: identityProxy.address as `0x${string}`,
        abi: identityArtifact.abi,
        functionName: "getVersion",
        args: [],
    });

    const reputationVersion = await publicClient.readContract({
        address: reputationProxy.address as `0x${string}`,
        abi: reputationArtifact.abi,
        functionName: "getVersion",
        args: [],
    });

    const reputationIdentity = await publicClient.readContract({
        address: reputationProxy.address as `0x${string}`,
        abi: reputationArtifact.abi,
        functionName: "getIdentityRegistry",
        args: [],
    });

    const validationVersion = await publicClient.readContract({
        address: validationProxy.address as `0x${string}`,
        abi: validationArtifact.abi,
        functionName: "getVersion",
        args: [],
    });

    const validationIdentity = await publicClient.readContract({
        address: validationProxy.address as `0x${string}`,
        abi: validationArtifact.abi,
        functionName: "getIdentityRegistry",
        args: [],
    });

    console.log("Versions:", { identityVersion, reputationVersion, validationVersion });
    console.log("Identity links:", { reputationIdentity, validationIdentity });

    console.log("Deployment summary:");
    console.log({
        proxies: { identity: identityProxy.address, reputation: reputationProxy.address, validation: validationProxy.address },
        implementations: { identity: identityImpl.address, reputation: reputationImpl.address, validation: validationImpl.address },
    });

    return {
        proxies: { identity: identityProxy.address, reputation: reputationProxy.address, validation: validationProxy.address },
        implementations: { identity: identityImpl.address, reputation: reputationImpl.address, validation: validationImpl.address },
    };
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
