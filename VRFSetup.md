# Chainlink VRF Setup Guide

This guide explains how to set up Chainlink VRF for the GameFi platform.

## Prerequisites

1. Testnet ETH/MATIC for gas fees
2. Testnet LINK tokens for VRF subscription funding
3. Access to Chainlink VRF Coordinator contracts

## Network Configuration

### Polygon Amoy Testnet

- **VRF Coordinator:** `0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2`
- **Key Hash (500 gwei):** `0x6b906fb3f8c8cf9d12b5f3b2e0c49071c00aa7e8fa24efe32c4baed8e7f9b36e`
- **LINK Token:** `0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904`
- **LINK Faucet:** https://faucets.chain.link/polygon-amoy

### Arbitrum Sepolia Testnet

- **VRF Coordinator:** `0x5CE8D5A2BC84beb22a398CCA51996F7930313D61`
- **Key Hash (150 gwei):** `0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be`
- **LINK Token:** `0xb1D4538B4571d411F07960EF2838Ce337FE1E80E`
- **LINK Faucet:** https://faucets.chain.link/arbitrum-sepolia

## Step-by-Step Setup

### 1. Get Testnet Tokens

```bash
# For Polygon Amoy - get MATIC from faucet
# Visit: https://faucet.polygon.technology/

# For Arbitrum Sepolia - get ETH from faucet  
# Visit: https://faucet.quicknode.com/arbitrum/sepolia

# Get LINK tokens from Chainlink faucet
# Visit the appropriate LINK faucet URL above
```

### 2. Create VRF Subscription

Visit [Chainlink VRF UI](https://vrf.chain.link/) and:

1. Connect your wallet
2. Switch to the correct testnet
3. Click "Create Subscription"
4. Fund the subscription with LINK tokens (minimum 2 LINK recommended)
5. Note down the Subscription ID

### 3. Configure Environment Variables

Create a `.env` file based on `.env.example`:

```bash
# Copy the example file
cp .env.example .env

# Edit the .env file with your values
# For Polygon Amoy:
POLYGON_VRF_COORDINATOR=0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2
POLYGON_KEY_HASH=0x6b906fb3f8c8cf9d12b5f3b2e0c49071c00aa7e8fa24efe32c4baed8e7f9b36e
POLYGON_SUBSCRIPTION_ID=your_subscription_id_here

# For Arbitrum Sepolia:
ARBITRUM_VRF_COORDINATOR=0x5CE8D5A2BC84beb22a398CCA51996F7930313D61
ARBITRUM_KEY_HASH=0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be
ARBITRUM_SUBSCRIPTION_ID=your_subscription_id_here

# Other required variables
PRIVATE_KEY=your_private_key_without_0x_prefix
TREASURY_ADDRESS=your_treasury_address
ADMIN_ADDRESS=your_admin_address
```

### 4. Deploy Contracts

```bash
# For Polygon Amoy
forge script script/Deploy.s.sol:Deploy --rpc-url $POLYGON_AMOY_RPC --broadcast --verify

# For Arbitrum Sepolia
forge script script/Deploy.s.sol:Deploy --rpc-url $ARBITRUM_SEPOLIA_RPC --broadcast --verify
```

### 5. Add Contract as VRF Consumer

After deployment, you need to add the CoinFlip contract as a consumer to your VRF subscription:

1. Go back to [Chainlink VRF UI](https://vrf.chain.link/)
2. Find your subscription
3. Click "Add Consumer"
4. Enter the deployed CoinFlip contract address
5. Confirm the transaction

### 6. Verify Setup

Run the verification script to ensure everything is working:

```bash
# Test the VRF setup
forge test --match-test testCoinFlipVRF -vv
```

## Troubleshooting

### Common Issues

1. **"InvalidConsumer" error**
   - Make sure the CoinFlip contract is added as a consumer to your VRF subscription
   - Verify the subscription ID is correct

2. **"InsufficientFunds" error**
   - Fund your VRF subscription with more LINK tokens
   - Check the current balance on the VRF UI

3. **VRF request timeout**
   - Increase gas limit in callback (currently set to 200,000)
   - Check network congestion on testnet

4. **"InvalidKeyHash" error**
   - Verify you're using the correct key hash for your target network
   - Check the official Chainlink documentation for updated values

### Gas Optimization

- Key hash selection affects gas costs:
  - Polygon Amoy: 500 gwei key hash for faster responses
  - Arbitrum Sepolia: 150 gwei key hash for cost efficiency

### Subscription Management

- Monitor LINK balance regularly
- Set up automatic top-ups if needed
- Remove unused consumers to save on costs

## Additional Resources

- [Chainlink VRF Documentation](https://docs.chain.link/vrf/v2/introduction)
- [VRF Best Practices](https://docs.chain.link/vrf/v2/best-practices)
- [Testnet Faucets](https://docs.chain.link/resources/link-token-contracts#testnet)

## Security Considerations

1. **Private Key Security**
   - Never commit private keys to version control
   - Use environment variables or secure key management
   - Consider using hardware wallets for mainnet deployment

2. **Subscription Security**
   - Only add trusted contracts as consumers
   - Monitor subscription usage and fund levels
   - Set up alerts for low LINK balance

3. **Contract Security**
   - The CoinFlip contract includes timeout mechanisms for failed VRF requests
   - Players can cancel bets if VRF doesn't respond within 200 blocks
   - Emergency pause functionality is available for admin

## Support

If you encounter issues:

1. Check the [Chainlink Discord](https://discord.gg/chainlink) for community support
2. Review the official documentation
3. Verify your network configuration and subscription setup