# Foundry Migration Guide

This project has been successfully migrated from Hardhat to Foundry and configured for deployment on Taiko's Shanghai EVM.

## Key Changes

### 1. Shanghai EVM Compatibility
- **Solidity Version**: Updated to 0.8.27 (from 0.8.20)
- **EVM Version**: Configured to target Shanghai EVM (`evm_version = "shanghai"`)
- **No PUSH0 Opcode**: By setting `evm_version = "shanghai"`, the compiler will not generate the PUSH0 opcode (introduced in Cancun), ensuring compatibility with Taiko's Shanghai EVM

### 2. Build System
- Migrated from Hardhat to Foundry
- Removed all test files (as requested)
- Cleaned up Hardhat artifacts and configuration files
- Updated package.json with Foundry commands

### 3. Contract Changes
- Created shared `IIdentityRegistry` interface in `contracts/interfaces/` to eliminate duplicate interface definitions
- All contracts now import this shared interface

## Project Structure

```
.
├── contracts/
│   ├── interfaces/
│   │   └── IIdentityRegistry.sol
│   ├── IdentityRegistry.sol
│   ├── ReputationRegistry.sol
│   ├── ValidationRegistry.sol
│   ├── IdentityRegistryUpgradeable.sol
│   ├── ReputationRegistryUpgradeable.sol
│   ├── ValidationRegistryUpgradeable.sol
│   ├── ERC1967Proxy.sol
│   └── MockERC1271Wallet.sol
├── script/
│   ├── Deploy.s.sol (Non-upgradeable deployment)
│   └── DeployUpgradeable.s.sol (Upgradeable deployment)
├── lib/ (Foundry dependencies)
├── foundry.toml
└── package.json
```

## Building

```bash
# Build all contracts
forge build

# Or use npm scripts
npm run build
```

## Deployment

### Environment Setup

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Fill in your private key and RPC URL in `.env`:
```
PRIVATE_KEY=your_private_key_without_0x
RPC_URL=https://rpc.test.taiko.xyz
ETHERSCAN_API_KEY=your_api_key
```

### Deploy Non-Upgradeable Contracts

```bash
# Deploy to custom RPC
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify

# Or use npm script
npm run deploy
```

### Deploy Upgradeable Contracts

```bash
# Deploy to Taiko Testnet
forge script script/DeployUpgradeable.s.sol:DeployUpgradeableScript --rpc-url taiko_testnet --broadcast --verify

# Or use npm scripts
npm run deploy:taiko-testnet  # For testnet
npm run deploy:taiko-mainnet  # For mainnet
```

## Taiko Network Configuration

The following network configurations are pre-configured in `foundry.toml`:

**Taiko Testnet (Hekla)**:
- RPC: https://rpc.test.taiko.xyz
- Explorer: https://blockscoutapi.test.taiko.xyz

**Taiko Mainnet**:
- RPC: https://rpc.taiko.xyz
- Explorer: https://blockscoutapi.taiko.xyz

## Verification

Contracts will be automatically verified if you include the `--verify` flag during deployment and have set `ETHERSCAN_API_KEY` in your `.env` file.

## Additional Commands

```bash
# Format contracts
npm run format

# Check formatting
npm run format:check

# Clean build artifacts
npm run clean
```

## Shanghai EVM Compatibility Notes

The project is configured to compile for Shanghai EVM, which means:
- No PUSH0 opcode will be used (introduced in Cancun)
- All OpenZeppelin contracts are compiled with Shanghai target
- Compatible with Taiko's EVM version
- Uses `via_ir = true` for optimal compilation with Shanghai EVM

## Dependencies

The project uses:
- OpenZeppelin Contracts v5.1.0
- OpenZeppelin Contracts Upgradeable v5.1.0
- Forge Std (latest)

All dependencies are managed through Foundry's `lib/` directory.
