# 🎮 Crypto Gaming Platform

A comprehensive, decentralized GameFi platform built on Ethereum-compatible networks (Polygon, Arbitrum). This project implements a full-stack gaming ecosystem featuring NFT-based access, tokenomics, DAO governance, cross-chain bridging, and multiple on-chain games.

## 🌟 Features

### Phase 1: Core Infrastructure & Basic Games
- **GameToken (GAME)**: ERC-20 utility token for the ecosystem.
- **GamePass (GPASS)**: ERC-721 NFT providing access to exclusive features and games.
- **PrizePool**: Secure vault for managing game rewards and payouts.
- **CoinFlip Game**: Provably fair betting game using Chainlink VRF for randomness.

### Phase 2: Advanced Gaming & Economy
- **Lottery System**: Periodic lottery with ticket purchasing and automated draws.
- **PvP Betting**: Peer-to-peer betting system for competitive gaming.
- **Staking Pool**: Yield farming mechanism for staking GAME tokens.
- **NFT Marketplace**: Trading platform for GamePass NFTs and in-game assets.
- **Pass Upgrade System**: Mechanics to level up NFTs for enhanced benefits.

### Phase 3: Governance & Expansion (Current State)
- **Cross-Chain Bridge**: Secure bridging of tokens and NFTs between Polygon, Arbitrum, and zkSync.
- **DAO Governance**: Decentralized decision-making for platform parameters and treasury management.
- **Tournament System**: Organized competitive events with prize pools and leaderboards.
- **Advanced Tokenomics**: Deflationary mechanisms, buybacks, and dynamic fee adjustments.
- **AI Analytics Engine**: On-chain data tracking for user behavior and game performance.
- **Social GameFi**: User profiles, reputation systems, and social interaction features.

## 🎯 Project Ambition (Finalized)

This platform aims to deliver a complete, production-grade GameFi ecosystem with:

- **Trust-minimized gameplay**: All core game outcomes and payouts verified on-chain.
- **Composable economy**: ERC-20 utility token, NFT access passes, staking, and marketplaces with consistent tokenomics.
- **Governed evolution**: A DAO that can safely tune parameters, treasury management, and feature rollouts.
- **Multi-chain presence**: Deployments across Polygon and Arbitrum testnets with a clear path to mainnet.
- **Player-first UX**: A responsive Next.js frontend with wallet connectivity and clear game flows.

Out of scope for this release: integrating new game genres or third-party studios, which will be scoped in future milestones.

## 🏗 Architecture

The platform utilizes a modular architecture powered by **Foundry** for smart contracts and **Next.js** for the frontend.

- **Smart Contracts**: Solidity v0.8.19
- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **Testing**: Forge (Foundry) with fuzzing and invariant testing
- **Oracles**: Chainlink VRF for randomness
- **Deployment**: Script-based deployment for multi-chain support

## 🚀 Getting Started

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (v18+)
- [Git LFS](https://git-lfs.com/)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/AryaSingh22/Crypto-Gaming-Platform.git
    cd Crypto-Gaming-Platform
    ```

2.  **Install dependencies:**
    ```bash
    forge install
    cd frontend && npm install
    ```

3.  **Environment Setup:**
    Copy `.env.example` to `.env` and fill in your API keys and private keys.
    ```bash
    cp .env.example .env
    ```
    Copy the frontend environment template:
    ```bash
    cp frontend/.env.example frontend/.env.local
    ```

### Running Tests

Run the comprehensive test suite covering all phases:
```bash
forge test
```

To run specific Phase 3 tests:
```bash
forge test --match-path test/CrossChainBridge.t.sol
forge test --match-path test/GameFiDAO.t.sol
```

### Deployment

Deploy to a supported network (e.g., Polygon Amoy):
```bash
forge script script/DeployPhase3.s.sol --rpc-url <YOUR_RPC_URL> --broadcast
```

### Deployment Readiness Checklist

- ✅ `.env` and `frontend/.env.local` filled with production values.
- ✅ `forge test` passes and frontend `lint`/`type-check` are clean.
- ✅ Deployment script points to the correct RPC URL and chain ID.
- ✅ Admin and treasury addresses verified and secured.
- ✅ VRF subscription funded and correctly configured for the target chain.

## 📂 Project Structure

```
├── src/                    # Smart Contract Source Code
│   ├── bridge/             # Cross-Chain Bridge
│   ├── governance/         # DAO & Voting
│   ├── tournaments/        # Tournament Logic
│   ├── tokenomics/         # Advanced Tokenomics
│   ├── social/             # Social Features
│   ├── analytics/          # AI Analytics
│   ├── GameToken.sol       # Core Token
│   ├── GamePass.sol        # Core NFT
│   └── ...
├── test/                   # Foundry Tests
├── script/                 # Deployment Scripts
├── frontend/               # Next.js Application
│   ├── src/components/     # React Components
│   └── ...
└── foundry.toml            # Foundry Configuration
```

## 🛡 Security

- **Access Control**: Role-based permissions (Admin, Operator, Validator).
- **Pausability**: Emergency pause functionality for all critical contracts.
- **Reentrancy Protection**: `ReentrancyGuard` used on all state-changing external calls.
- **Randomness**: Chainlink VRF ensures tamper-proof RNG for games.

## 📜 License

This project is licensed under the MIT License.
