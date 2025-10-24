# ERC-8004 Network Deployments

This document lists all deployed ERC-8004 contract addresses across various networks.

## Testnet Deployments

### ETH Sepolia

| Contract | Address | Explorer |
|----------|---------|----------|
| **IdentityRegistry** | `0x8004a6090Cd10A7288092483047B097295Fb8847` | [View on Etherscan](https://sepolia.etherscan.io/address/0x8004a6090Cd10A7288092483047B097295Fb8847) |
| **ReputationRegistry** | `0x8004B8FD1A363aa02fDC07635C0c5F94f6Af5B7E` | [View on Etherscan](https://sepolia.etherscan.io/address/0x8004B8FD1A363aa02fDC07635C0c5F94f6Af5B7E) |
| **ValidationRegistry** | `0x8004CB39f29c09145F24Ad9dDe2A108C1A2cdfC5` | [View on Etherscan](https://sepolia.etherscan.io/address/0x8004CB39f29c09145F24Ad9dDe2A108C1A2cdfC5) |

### Base Sepolia

| Contract | Address | Explorer |
|----------|---------|----------|
| **IdentityRegistry** | `0x8004AA63c570c570eBF15376c0dB199918BFe9Fb` | [View on BaseScan](https://sepolia.basescan.org/address/0x8004AA63c570c570eBF15376c0dB199918BFe9Fb) |
| **ReputationRegistry** | `0x8004bd8daB57f14Ed299135749a5CB5c42d341BF` | [View on BaseScan](https://sepolia.basescan.org/address/0x8004bd8daB57f14Ed299135749a5CB5c42d341BF) |
| **ValidationRegistry** | `0x8004C269D0A5647E51E121FeB226200ECE932d55` | [View on BaseScan](https://sepolia.basescan.org/address/0x8004C269D0A5647E51E121FeB226200ECE932d55) |

### Linea Sepolia

| Contract | Address | Explorer |
|----------|---------|----------|
| **IdentityRegistry** | `0x8004aa7C931bCE1233973a0C6A667f73F66282e7` | [View on LineaScan](https://sepolia.lineascan.build/address/0x8004aa7C931bCE1233973a0C6A667f73F66282e7) |
| **ReputationRegistry** | `0x8004bd8483b99310df121c46ED8858616b2Bba02` | [View on LineaScan](https://sepolia.lineascan.build/address/0x8004bd8483b99310df121c46ED8858616b2Bba02) |
| **ValidationRegistry** | `0x8004c44d1EFdd699B2A26e781eF7F77c56A9a4EB` | [View on LineaScan](https://sepolia.lineascan.build/address/0x8004c44d1EFdd699B2A26e781eF7F77c56A9a4EB) |

### Hedera Testnet

| Contract | Address | Explorer |
|----------|---------|----------|
| **IdentityRegistry** | `0x4c74ebd72921d537159ed2053f46c12a7d8e5923` | [View on HashScan](https://hashscan.io/testnet/contract/0x4c74ebd72921d537159ed2053f46c12a7d8e5923) |
| **ReputationRegistry** | `0xc565edcba77e3abeade40bfd6cf6bf583b3293e0` | [View on HashScan](https://hashscan.io/testnet/contract/0xc565edcba77e3abeade40bfd6cf6bf583b3293e0) |
| **ValidationRegistry** | `0x18df085d85c586e9241e0cd121ca422f571c2da6` | [View on HashScan](https://hashscan.io/testnet/contract/0x18df085d85c586e9241e0cd121ca422f571c2da6) |

## Mainnet Deployments

_No mainnet deployments yet._

---

## Network Information

### Supported Networks

| Network | Chain ID | RPC URL | Type |
|---------|----------|---------|------|
| ETH Sepolia | 11155111 | https://sepolia.infura.io/v3/YOUR-API-KEY | Testnet |
| Base Sepolia | 84532 | https://sepolia.base.org | Testnet |
| Linea Sepolia | 59141 | https://rpc.sepolia.linea.build | Testnet |
| Hedera Testnet | 296 | https://testnet.hashio.io/api | Testnet |

### Contract Versions

All deployed contracts use:
- **Solidity Version**: 0.8.28
- **OpenZeppelin Contracts**: v5.4.0
- **Optimizer**: Enabled (200 runs)
- **Via IR**: Enabled

## Deployment Notes

- All contracts follow the ERC-8004 specification
- Contracts are deployed as non-upgradeable versions
- For upgradeable deployments, use the `*Upgradeable.sol` variants with ERC1967Proxy
- Verify contract source code on block explorers after deployment

## Adding New Deployments

When deploying to a new network, please update this file with:
1. Network name and type (testnet/mainnet)
2. All three contract addresses
3. Block explorer links
4. Chain ID and RPC information
5. Deployment date and deployer address (optional)

## Security

⚠️ **Testnet Warning**: These are testnet deployments for development and testing purposes only. Do not use them for production applications or store valuable assets.

For mainnet deployments, contracts should be:
- Thoroughly audited
- Tested extensively
- Deployed with proper access controls
- Documented with deployment parameters
