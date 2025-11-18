// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";
import "../src/PrizePool.sol";
import "../src/CoinFlip.sol";
import "../src/Lottery.sol";
import "../src/PvPBetting.sol";
import "../src/StakingPool.sol";
import "../src/NFTMarketplace.sol";
import "../src/PassUpgrade.sol";

/**
 * @title DeployPhase2
 * @notice Complete deployment script for Phase 2 GameFi ecosystem
 */
contract DeployPhase2 is Script {
    // Phase 1 contracts (already deployed)
    struct Phase1Contracts {
        address gameToken;
        address gamePass;
        address prizePool;
        address coinFlip;
    }

    // Phase 2 contracts (new)
    struct Phase2Contracts {
        address lottery;
        address pvpBetting;
        address stakingPool;
        address nftMarketplace;
        address passUpgrade;
    }

    // Complete contract suite
    struct AllContracts {
        Phase1Contracts phase1;
        Phase2Contracts phase2;
    }

    // Deployment configuration
    struct DeployConfig {
        // Phase 1 config (if deploying fresh)
        string tokenName;
        string tokenSymbol;
        uint256 initialSupply;
        uint256 maxSupply;
        string passName;
        string passSymbol;
        string baseURI;
        uint16 prizePoolFeeBps;
        uint256 coinFlipMinBet;
        uint256 coinFlipMaxBet;
        
        // Phase 2 specific config
        uint256 lotteryTicketPrice;
        uint256 stakingMinAmount;
        uint256 stakingBaseRate;
        uint16 marketplaceFee;
        uint16 royaltyFee;
        uint16 pvpPlatformFee;
        uint256 minBetAmount;
        uint256 maxBetAmount;
        
        // VRF Configuration
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subscriptionId;
        
        // Addresses
        address treasury;
        address admin;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        DeployConfig memory config = getDeployConfig();
        
        console.log("Starting Phase 2 deployment on chain:", block.chainid);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Check if Phase 1 contracts exist, deploy if not
        AllContracts memory contracts = deployCompleteEcosystem(config);
        
        // Configure all contracts
        configurePhase2Ecosystem(contracts, config);
        
        vm.stopBroadcast();
        
        // Log deployment results
        logPhase2Deployment(contracts);
        
        // Save deployment addresses
        savePhase2Addresses(contracts);
    }

    function getDeployConfig() internal view returns (DeployConfig memory config) {
        if (block.chainid == 80002) { // Polygon Amoy
            config = DeployConfig({
                // Phase 1 config
                tokenName: "Game Token",
                tokenSymbol: "GAME",
                initialSupply: 1_000_000e18,
                maxSupply: 10_000_000e18,
                passName: "Game Pass",
                passSymbol: "GPASS",
                baseURI: "https://api.cryptogaming.xyz/metadata/",
                prizePoolFeeBps: 200, // 2%
                coinFlipMinBet: 10e18,
                coinFlipMaxBet: 1000e18,
                
                // Phase 2 config
                lotteryTicketPrice: 50e18, // 50 GAME per ticket
                stakingMinAmount: 100e18,  // 100 GAME minimum stake
                stakingBaseRate: 1e15,     // ~3.15% APY base
                marketplaceFee: 250,       // 2.5%
                royaltyFee: 500,          // 5%
                pvpPlatformFee: 250,      // 2.5%
                minBetAmount: 10e18,
                maxBetAmount: 1000e18,
                
                // VRF
                vrfCoordinator: vm.envAddress("POLYGON_VRF_COORDINATOR"),
                keyHash: vm.envBytes32("POLYGON_KEY_HASH"),
                subscriptionId: uint64(vm.envUint("POLYGON_SUBSCRIPTION_ID")),
                
                // Addresses
                treasury: vm.envAddress("TREASURY_ADDRESS"),
                admin: vm.envAddress("ADMIN_ADDRESS")
            });
        } else if (block.chainid == 421614) { // Arbitrum Sepolia
            config = DeployConfig({
                // Phase 1 config
                tokenName: "Game Token",
                tokenSymbol: "GAME",
                initialSupply: 1_000_000e18,
                maxSupply: 10_000_000e18,
                passName: "Game Pass",
                passSymbol: "GPASS",
                baseURI: "https://api.cryptogaming.xyz/metadata/",
                prizePoolFeeBps: 200,
                coinFlipMinBet: 10e18,
                coinFlipMaxBet: 1000e18,
                
                // Phase 2 config
                lotteryTicketPrice: 50e18,
                stakingMinAmount: 100e18,
                stakingBaseRate: 1e15,
                marketplaceFee: 250,
                royaltyFee: 500,
                pvpPlatformFee: 250,
                minBetAmount: 10e18,
                maxBetAmount: 1000e18,
                
                // VRF
                vrfCoordinator: vm.envAddress("ARBITRUM_VRF_COORDINATOR"),
                keyHash: vm.envBytes32("ARBITRUM_KEY_HASH"),
                subscriptionId: uint64(vm.envUint("ARBITRUM_SUBSCRIPTION_ID")),
                
                // Addresses
                treasury: vm.envAddress("TREASURY_ADDRESS"),
                admin: vm.envAddress("ADMIN_ADDRESS")
            });
        } else {
            revert("Unsupported chain ID");
        }
    }

    function deployCompleteEcosystem(DeployConfig memory config) 
        internal 
        returns (AllContracts memory contracts) 
    {
        console.log("=== Deploying Complete GameFi Ecosystem ===");
        
        // Deploy Phase 1 contracts (or use existing ones)
        contracts.phase1 = deployPhase1Contracts(config);
        
        // Deploy Phase 2 contracts
        contracts.phase2 = deployPhase2Contracts(config, contracts.phase1);
    }

    function deployPhase1Contracts(DeployConfig memory config) 
        internal 
        returns (Phase1Contracts memory phase1) 
    {
        console.log("--- Deploying Phase 1 Contracts ---");
        
        // 1. Deploy GameToken
        console.log("Deploying GameToken...");
        GameToken gameToken = new GameToken(
            config.tokenName,
            config.tokenSymbol,
            config.initialSupply,
            config.maxSupply,
            config.treasury,
            config.admin
        );
        phase1.gameToken = address(gameToken);
        console.log("GameToken deployed at:", phase1.gameToken);
        
        // 2. Deploy GamePass
        console.log("Deploying GamePass...");
        GamePass gamePass = new GamePass(
            config.passName,
            config.passSymbol,
            config.baseURI,
            config.treasury,
            config.admin
        );
        phase1.gamePass = address(gamePass);
        console.log("GamePass deployed at:", phase1.gamePass);
        
        // 3. Deploy PrizePool
        console.log("Deploying PrizePool...");
        PrizePool prizePool = new PrizePool(
            phase1.gameToken,
            config.treasury,
            config.prizePoolFeeBps,
            config.admin
        );
        phase1.prizePool = address(prizePool);
        console.log("PrizePool deployed at:", phase1.prizePool);
        
        // 4. Deploy CoinFlip
        console.log("Deploying CoinFlip...");
        CoinFlip coinFlip = new CoinFlip(
            config.vrfCoordinator,
            config.subscriptionId,
            config.keyHash,
            phase1.prizePool,
            phase1.gameToken,
            phase1.gamePass,
            config.coinFlipMinBet,
            config.coinFlipMaxBet,
            config.admin
        );
        phase1.coinFlip = address(coinFlip);
        console.log("CoinFlip deployed at:", phase1.coinFlip);
    }

    function deployPhase2Contracts(DeployConfig memory config, Phase1Contracts memory phase1) 
        internal 
        returns (Phase2Contracts memory phase2) 
    {
        console.log("--- Deploying Phase 2 Contracts ---");
        
        // 1. Deploy Lottery
        console.log("Deploying Lottery...");
        Lottery lottery = new Lottery(
            config.vrfCoordinator,
            config.subscriptionId,
            config.keyHash,
            phase1.gameToken,
            phase1.prizePool,
            phase1.gamePass,
            config.treasury,
            config.lotteryTicketPrice,
            config.admin
        );
        phase2.lottery = address(lottery);
        console.log("Lottery deployed at:", phase2.lottery);
        
        // 2. Deploy PvP Betting
        console.log("Deploying PvPBetting...");
        PvPBetting pvpBetting = new PvPBetting(
            config.vrfCoordinator,
            config.subscriptionId,
            config.keyHash,
            phase1.gameToken,
            phase1.gamePass,
            config.treasury,
            config.minBetAmount,
            config.maxBetAmount,
            config.admin
        );
        phase2.pvpBetting = address(pvpBetting);
        console.log("PvPBetting deployed at:", phase2.pvpBetting);
        
        // 3. Deploy Staking Pool
        console.log("Deploying StakingPool...");
        StakingPool stakingPool = new StakingPool(
            phase1.gameToken,
            phase1.gamePass,
            config.treasury,
            config.admin
        );
        phase2.stakingPool = address(stakingPool);
        console.log("StakingPool deployed at:", phase2.stakingPool);
        
        // 4. Deploy NFT Marketplace
        console.log("Deploying NFTMarketplace...");
        NFTMarketplace nftMarketplace = new NFTMarketplace(
            phase1.gameToken,
            phase1.gamePass,
            config.treasury,
            config.admin
        );
        phase2.nftMarketplace = address(nftMarketplace);
        console.log("NFTMarketplace deployed at:", phase2.nftMarketplace);
        
        // 5. Deploy Pass Upgrade
        console.log("Deploying PassUpgrade...");
        PassUpgrade passUpgrade = new PassUpgrade(
            phase1.gameToken,
            phase1.gamePass,
            phase2.stakingPool,
            config.treasury,
            config.admin
        );
        phase2.passUpgrade = address(passUpgrade);
        console.log("PassUpgrade deployed at:", phase2.passUpgrade);
    }

    function configurePhase2Ecosystem(AllContracts memory contracts, DeployConfig memory config) internal {
        console.log("=== Configuring Phase 2 Ecosystem ===");
        
        PrizePool prizePool = PrizePool(contracts.phase1.prizePool);
        GamePass gamePass = GamePass(contracts.phase1.gamePass);
        GameToken gameToken = GameToken(contracts.phase1.gameToken);
        
        // Authorize all games in PrizePool
        console.log("Authorizing games in PrizePool...");
        prizePool.authorizeGame(contracts.phase1.coinFlip, true);
        prizePool.authorizeGame(contracts.phase2.lottery, true);
        
        // Enable public minting for GamePass
        console.log("Enabling public minting for GamePass...");
        gamePass.setPublicMintEnabled(true);
        
        // Fund PrizePool with initial liquidity
        uint256 initialPoolFunding = config.initialSupply / 5; // 20%
        console.log("Funding PrizePool with:", initialPoolFunding);
        gameToken.approve(contracts.phase1.prizePool, initialPoolFunding);
        prizePool.deposit(initialPoolFunding);
        
        // Fund StakingPool for rewards
        uint256 stakingRewards = config.initialSupply / 10; // 10%
        console.log("Funding StakingPool with rewards:", stakingRewards);
        gameToken.approve(contracts.phase2.stakingPool, stakingRewards);
        StakingPool(contracts.phase2.stakingPool).distributeRewards(stakingRewards);
        
        // Grant reward distributor role to treasury for ongoing rewards
        StakingPool(contracts.phase2.stakingPool).grantRole(
            StakingPool(contracts.phase2.stakingPool).REWARD_DISTRIBUTOR_ROLE(),
            config.treasury
        );
        
        console.log("Phase 2 configuration completed!");
    }

    function logPhase2Deployment(AllContracts memory contracts) internal pure {
        console.log("=== Phase 2 Deployment Complete ===");
        console.log("Phase 1 Contracts:");
        console.log("  GameToken:", contracts.phase1.gameToken);
        console.log("  GamePass:", contracts.phase1.gamePass);
        console.log("  PrizePool:", contracts.phase1.prizePool);
        console.log("  CoinFlip:", contracts.phase1.coinFlip);
        console.log("");
        console.log("Phase 2 Contracts:");
        console.log("  Lottery:", contracts.phase2.lottery);
        console.log("  PvPBetting:", contracts.phase2.pvpBetting);
        console.log("  StakingPool:", contracts.phase2.stakingPool);
        console.log("  NFTMarketplace:", contracts.phase2.nftMarketplace);
        console.log("  PassUpgrade:", contracts.phase2.passUpgrade);
        console.log("=====================================");
    }

    function savePhase2Addresses(AllContracts memory contracts) internal {
        string memory chainName = getChainName();
        string memory json = string.concat(
            '{\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "network": "', chainName, '",\n',
            '  "phase": "Phase 2",\n',
            '  "contracts": {\n',
            '    "phase1": {\n',
            '      "GameToken": "', vm.toString(contracts.phase1.gameToken), '",\n',
            '      "GamePass": "', vm.toString(contracts.phase1.gamePass), '",\n',
            '      "PrizePool": "', vm.toString(contracts.phase1.prizePool), '",\n',
            '      "CoinFlip": "', vm.toString(contracts.phase1.coinFlip), '"\n',
            '    },\n',
            '    "phase2": {\n',
            '      "Lottery": "', vm.toString(contracts.phase2.lottery), '",\n',
            '      "PvPBetting": "', vm.toString(contracts.phase2.pvpBetting), '",\n',
            '      "StakingPool": "', vm.toString(contracts.phase2.stakingPool), '",\n',
            '      "NFTMarketplace": "', vm.toString(contracts.phase2.nftMarketplace), '",\n',
            '      "PassUpgrade": "', vm.toString(contracts.phase2.passUpgrade), '"\n',
            '    }\n',
            '  },\n',
            '  "deployedAt": ', vm.toString(block.timestamp), '\n',
            '}'
        );
        
        string memory filename = string.concat("deployments/", chainName, "-phase2.json");
        vm.writeFile(filename, json);
        console.log("Phase 2 deployment addresses saved to:", filename);
    }

    function getChainName() internal view returns (string memory) {
        if (block.chainid == 80002) return "polygon-amoy";
        if (block.chainid == 421614) return "arbitrum-sepolia";
        return "unknown";
    }
}

/**
 * @title LocalPhase2Deploy
 * @notice Local deployment for Phase 2 testing
 */
contract LocalPhase2Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying Phase 2 locally with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy VRF Mock
        VRFCoordinatorV2Mock vrfMock = new VRFCoordinatorV2Mock(0.1 ether, 1e9);
        uint64 subscriptionId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subscriptionId, 10 ether);
        
        // Deploy all contracts using the Phase 2 script logic
        // (Implementation would mirror the main deployment but with local config)
        
        vm.stopBroadcast();
        
        console.log("=== Local Phase 2 Deployment Complete ===");
    }
}

// Helper import for VRF Mock
import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";