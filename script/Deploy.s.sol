// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";
import "../src/PrizePool.sol";
import "../src/CoinFlip.sol";

/**
 * @title Deploy
 * @notice Deployment script for the GameFi platform contracts
 * @dev Deploys all contracts and sets up initial configuration
 */
contract Deploy is Script {
    // Deployment configuration
    struct DeployConfig {
        string tokenName;
        string tokenSymbol;
        uint256 initialSupply;
        uint256 maxSupply;
        string passName;
        string passSymbol;
        string baseURI;
        uint16 feeBps;
        uint256 minBet;
        uint256 maxBet;
        address vrfCoordinator;
        bytes32 keyHash;
        uint64 subscriptionId;
        address treasury;
        address admin;
    }

    // Deployed contract addresses
    struct DeployedContracts {
        address gameToken;
        address gamePass;
        address prizePool;
        address coinFlip;
    }

    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Load configuration based on chain
        DeployConfig memory config = getDeployConfig();
        
        console.log("Starting deployment on chain:", block.chainid);
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Treasury:", config.treasury);
        console.log("Admin:", config.admin);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contracts
        DeployedContracts memory contracts = deployContracts(config);
        
        // Configure contracts
        configureContracts(contracts, config);
        
        vm.stopBroadcast();
        
        // Log deployment results
        logDeployment(contracts);
        
        // Save deployment addresses
        saveDeploymentAddresses(contracts);
    }

    function getDeployConfig() internal view returns (DeployConfig memory config) {
        if (block.chainid == 80002) { // Polygon Amoy
            config = DeployConfig({
                tokenName: "Game Token",
                tokenSymbol: "GAME",
                initialSupply: 1_000_000e18,
                maxSupply: 10_000_000e18,
                passName: "Game Pass",
                passSymbol: "GPASS",
                baseURI: "https://api.cryptogaming.xyz/metadata/",
                feeBps: 200, // 2%
                minBet: 10e18,
                maxBet: 1000e18,
                vrfCoordinator: vm.envAddress("POLYGON_VRF_COORDINATOR"),
                keyHash: vm.envBytes32("POLYGON_KEY_HASH"),
                subscriptionId: uint64(vm.envUint("POLYGON_SUBSCRIPTION_ID")),
                treasury: vm.envAddress("TREASURY_ADDRESS"),
                admin: vm.envAddress("ADMIN_ADDRESS")
            });
        } else if (block.chainid == 421614) { // Arbitrum Sepolia
            config = DeployConfig({
                tokenName: "Game Token",
                tokenSymbol: "GAME",
                initialSupply: 1_000_000e18,
                maxSupply: 10_000_000e18,
                passName: "Game Pass",
                passSymbol: "GPASS",
                baseURI: "https://api.cryptogaming.xyz/metadata/",
                feeBps: 200, // 2%
                minBet: 10e18,
                maxBet: 1000e18,
                vrfCoordinator: vm.envAddress("ARBITRUM_VRF_COORDINATOR"),
                keyHash: vm.envBytes32("ARBITRUM_KEY_HASH"),
                subscriptionId: uint64(vm.envUint("ARBITRUM_SUBSCRIPTION_ID")),
                treasury: vm.envAddress("TREASURY_ADDRESS"),
                admin: vm.envAddress("ADMIN_ADDRESS")
            });
        } else {
            revert("Unsupported chain ID");
        }
    }

    function deployContracts(DeployConfig memory config) 
        internal 
        returns (DeployedContracts memory contracts) 
    {
        console.log("=== Deploying Contracts ===");
        
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
        contracts.gameToken = address(gameToken);
        console.log("GameToken deployed at:", contracts.gameToken);
        
        // 2. Deploy GamePass
        console.log("Deploying GamePass...");
        GamePass gamePass = new GamePass(
            config.passName,
            config.passSymbol,
            config.baseURI,
            config.treasury,
            config.admin
        );
        contracts.gamePass = address(gamePass);
        console.log("GamePass deployed at:", contracts.gamePass);
        
        // 3. Deploy PrizePool
        console.log("Deploying PrizePool...");
        PrizePool prizePool = new PrizePool(
            contracts.gameToken,
            config.treasury,
            config.feeBps,
            config.admin
        );
        contracts.prizePool = address(prizePool);
        console.log("PrizePool deployed at:", contracts.prizePool);
        
        // 4. Deploy CoinFlip
        console.log("Deploying CoinFlip...");
        CoinFlip coinFlip = new CoinFlip(
            config.vrfCoordinator,
            config.subscriptionId,
            config.keyHash,
            contracts.prizePool,
            contracts.gameToken,
            contracts.gamePass,
            config.minBet,
            config.maxBet,
            config.admin
        );
        contracts.coinFlip = address(coinFlip);
        console.log("CoinFlip deployed at:", contracts.coinFlip);
    }

    function configureContracts(
        DeployedContracts memory contracts, 
        DeployConfig memory config
    ) internal {
        console.log("=== Configuring Contracts ===");
        
        PrizePool prizePool = PrizePool(contracts.prizePool);
        GamePass gamePass = GamePass(contracts.gamePass);
        GameToken gameToken = GameToken(contracts.gameToken);
        
        // Authorize CoinFlip in PrizePool
        console.log("Authorizing CoinFlip in PrizePool...");
        prizePool.authorizeGame(contracts.coinFlip, true);
        
        // Enable public minting for GamePass
        console.log("Enabling public minting for GamePass...");
        gamePass.setPublicMintEnabled(true);
        
        // Initial funding of PrizePool (10% of initial supply)
        uint256 initialPoolFunding = config.initialSupply / 10;
        console.log("Funding PrizePool with:", initialPoolFunding);
        
        // Transfer tokens from treasury to PrizePool
        gameToken.approve(contracts.prizePool, initialPoolFunding);
        prizePool.deposit(initialPoolFunding);
        
        console.log("Configuration completed!");
    }

    function logDeployment(DeployedContracts memory contracts) internal pure {
        console.log("=== Deployment Summary ===");
        console.log("GameToken:", contracts.gameToken);
        console.log("GamePass:", contracts.gamePass);
        console.log("PrizePool:", contracts.prizePool);
        console.log("CoinFlip:", contracts.coinFlip);
        console.log("==============================");
    }

    function saveDeploymentAddresses(DeployedContracts memory contracts) internal {
        string memory chainName = getChainName();
        string memory json = string.concat(
            '{\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "network": "', chainName, '",\n',
            '  "contracts": {\n',
            '    "GameToken": "', vm.toString(contracts.gameToken), '",\n',
            '    "GamePass": "', vm.toString(contracts.gamePass), '",\n',
            '    "PrizePool": "', vm.toString(contracts.prizePool), '",\n',
            '    "CoinFlip": "', vm.toString(contracts.coinFlip), '"\n',
            '  },\n',
            '  "deployedAt": ', vm.toString(block.timestamp), '\n',
            '}'
        );
        
        string memory filename = string.concat("deployments/", chainName, ".json");
        vm.writeFile(filename, json);
        console.log("Deployment addresses saved to:", filename);
    }

    function getChainName() internal view returns (string memory) {
        if (block.chainid == 80002) return "polygon-amoy";
        if (block.chainid == 421614) return "arbitrum-sepolia";
        return "unknown";
    }
}

/**
 * @title DeployLocal
 * @notice Local deployment script for testing with VRF mock
 */
contract DeployLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // Anvil default
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying locally with deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy VRF Mock first
        console.log("Deploying VRF Mock...");
        VRFCoordinatorV2Mock vrfMock = new VRFCoordinatorV2Mock(0.1 ether, 1e9);
        uint64 subscriptionId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subscriptionId, 10 ether);
        
        // Deploy GameToken
        GameToken gameToken = new GameToken(
            "Game Token",
            "GAME",
            1_000_000e18,
            10_000_000e18,
            deployer, // treasury
            deployer  // admin
        );
        
        // Deploy GamePass
        GamePass gamePass = new GamePass(
            "Game Pass",
            "GPASS",
            "https://api.example.com/metadata/",
            deployer, // treasury
            deployer  // admin
        );
        
        // Deploy PrizePool
        PrizePool prizePool = new PrizePool(
            address(gameToken),
            deployer, // treasury
            200,      // 2% fee
            deployer  // admin
        );
        
        // Deploy CoinFlip
        CoinFlip coinFlip = new CoinFlip(
            address(vrfMock),
            subscriptionId,
            0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // dummy key hash
            address(prizePool),
            address(gameToken),
            address(gamePass),
            10e18,    // min bet
            1000e18,  // max bet
            deployer  // admin
        );
        
        // Add CoinFlip as VRF consumer
        vrfMock.addConsumer(subscriptionId, address(coinFlip));
        
        // Configure contracts
        prizePool.authorizeGame(address(coinFlip), true);
        gamePass.setPublicMintEnabled(true);
        
        // Fund PrizePool
        gameToken.approve(address(prizePool), 100_000e18);
        prizePool.deposit(100_000e18);
        
        vm.stopBroadcast();
        
        console.log("=== Local Deployment Complete ===");
        console.log("VRF Mock:", address(vrfMock));
        console.log("GameToken:", address(gameToken));
        console.log("GamePass:", address(gamePass));
        console.log("PrizePool:", address(prizePool));
        console.log("CoinFlip:", address(coinFlip));
        console.log("VRF Subscription ID:", subscriptionId);
    }
}

// Helper import for VRF Mock in local deployment
import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";