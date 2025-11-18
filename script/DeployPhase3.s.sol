// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Phase 3 Contracts
import "../src/bridge/CrossChainBridge.sol";
import "../src/governance/GameFiDAO.sol";
import "../src/tournaments/TournamentSystem.sol";
import "../src/tokenomics/AdvancedTokenomics.sol";
import "../src/analytics/AIAnalyticsEngine.sol";
import "../src/social/SocialGameFi.sol";

// Existing contracts (assume they're deployed)
import "../src/GameToken.sol";
import "../src/GamePass.sol";
import "../src/MonitoringSystem.sol";

/**
 * @title DeployPhase3
 * @dev Deployment script for Phase 3 scaling features: Cross-chain, DAO, Tournaments, Advanced Tokenomics, AI Analytics, and Social Features
 */
contract DeployPhase3 is Script {
    // Network configurations
    struct NetworkConfig {
        uint256 chainId;
        string name;
        address gameToken;
        address gamePass;
        address monitoringSystem;
        address treasury;
        bool isTestnet;
    }

    // Deployment addresses will be stored here
    struct Phase3Deployment {
        address crossChainBridge;
        address governanceToken;
        address gameFiDAO;
        address tournamentSystem;
        address advancedTokenomics;
        address aiAnalyticsEngine;
        address socialGameFi;
    }

    // Network configurations
    mapping(uint256 => NetworkConfig) public networks;
    Phase3Deployment public deployment;

    // Constants
    uint256 constant INITIAL_DAO_SUPPLY = 100_000_000 * 10**18; // 100M tokens
    uint256 constant VOTING_DELAY = 1 days;
    uint256 constant VOTING_PERIOD = 7 days;
    uint256 constant PROPOSAL_THRESHOLD = 1_000_000 * 10**18; // 1M tokens to propose
    uint256 constant QUORUM_THRESHOLD = 10; // 10% quorum

    function setUp() public {
        // Ethereum Mainnet
        networks[1] = NetworkConfig({
            chainId: 1,
            name: "Ethereum Mainnet",
            gameToken: address(0), // Will be set during deployment
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: address(0),
            isTestnet: false
        });

        // Polygon Mainnet
        networks[137] = NetworkConfig({
            chainId: 137,
            name: "Polygon Mainnet",
            gameToken: address(0),
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: address(0),
            isTestnet: false
        });

        // Arbitrum One
        networks[42161] = NetworkConfig({
            chainId: 42161,
            name: "Arbitrum One",
            gameToken: address(0),
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: address(0),
            isTestnet: false
        });

        // zkSync Era
        networks[324] = NetworkConfig({
            chainId: 324,
            name: "zkSync Era",
            gameToken: address(0),
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: address(0),
            isTestnet: false
        });

        // Polygon Amoy Testnet
        networks[80002] = NetworkConfig({
            chainId: 80002,
            name: "Polygon Amoy",
            gameToken: address(0),
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: address(0),
            isTestnet: true
        });

        // Arbitrum Sepolia
        networks[421614] = NetworkConfig({
            chainId: 421614,
            name: "Arbitrum Sepolia",
            gameToken: address(0),
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: address(0),
            isTestnet: true
        });
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        uint256 currentChainId = block.chainid;

        console.log("Deploying Phase 3 contracts on chain:", currentChainId);
        console.log("Deployer address:", deployer);

        NetworkConfig memory config = networks[currentChainId];
        require(bytes(config.name).length > 0, "Unsupported network");

        vm.startBroadcast(deployerPrivateKey);

        // If this is a fresh deployment, deploy core contracts first
        if (config.gameToken == address(0)) {
            _deployCore(config);
        }

        // Deploy Phase 3 contracts
        _deployPhase3(config);

        // Configure contracts
        _configurePhase3();

        // Setup cross-chain configurations
        if (currentChainId == 1 || currentChainId == 137 || currentChainId == 42161 || currentChainId == 324) {
            _setupCrossChain(currentChainId);
        }

        vm.stopBroadcast();

        // Log deployment addresses
        _logDeployment(config);
    }

    function _deployCore(NetworkConfig memory config) internal view {
        console.log("Deploying core contracts...");

        // For Phase 3, assume core contracts are already deployed
        // This deployment script focuses on Phase 3 features only
        require(config.gameToken != address(0), "GameToken must be deployed first");
        require(config.gamePass != address(0), "GamePass must be deployed first");
        require(config.monitoringSystem != address(0), "MonitoringSystem must be deployed first");
        
        console.log("Using existing core contracts:");
        console.log("GameToken:", config.gameToken);
        console.log("GamePass:", config.gamePass);
        console.log("MonitoringSystem:", config.monitoringSystem);

        // Set treasury to deployer if not set
        if (config.treasury == address(0)) {
            config.treasury = msg.sender;
        }
    }

    function _deployPhase3(NetworkConfig memory config) internal {
        console.log("Deploying Phase 3 contracts...");

        // 1. Deploy CrossChainBridge
        CrossChainBridge crossChainBridge = new CrossChainBridge();
        deployment.crossChainBridge = address(crossChainBridge);
        console.log("CrossChainBridge deployed at:", address(crossChainBridge));

        // 2. Deploy GovernanceToken
        GovernanceToken governanceToken = new GovernanceToken();
        deployment.governanceToken = address(governanceToken);
        console.log("GovernanceToken deployed at:", address(governanceToken));

        // 3. Deploy GameFiDAO
        GameFiDAO gameFiDAO = new GameFiDAO(
            address(governanceToken),
            config.treasury,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD
        );
        deployment.gameFiDAO = address(gameFiDAO);
        console.log("GameFiDAO deployed at:", address(gameFiDAO));

        // 4. Deploy TournamentSystem
        TournamentSystem tournamentSystem = new TournamentSystem(
            config.gameToken,
            config.treasury,
            config.monitoringSystem
        );
        deployment.tournamentSystem = address(tournamentSystem);
        console.log("TournamentSystem deployed at:", address(tournamentSystem));

        // 5. Deploy AdvancedTokenomics
        AdvancedTokenomics advancedTokenomics = new AdvancedTokenomics(
            config.gameToken,
            config.treasury,
            config.gameToken, // Using gameToken as liquidity pool for simplicity
            config.monitoringSystem
        );
        deployment.advancedTokenomics = address(advancedTokenomics);
        console.log("AdvancedTokenomics deployed at:", address(advancedTokenomics));

        // 6. Deploy AIAnalyticsEngine
        AIAnalyticsEngine aiAnalyticsEngine = new AIAnalyticsEngine(
            config.monitoringSystem
        );
        deployment.aiAnalyticsEngine = address(aiAnalyticsEngine);
        console.log("AIAnalyticsEngine deployed at:", address(aiAnalyticsEngine));

        // 7. Deploy SocialGameFi
        SocialGameFi socialGameFi = new SocialGameFi(
            config.gameToken,
            config.treasury,
            config.monitoringSystem
        );
        deployment.socialGameFi = address(socialGameFi);
        console.log("SocialGameFi deployed at:", address(socialGameFi));
    }

    function _configurePhase3() internal {
        console.log("Configuring Phase 3 contracts...");

        // Configure governance token minting rights
        GovernanceToken governanceToken = GovernanceToken(deployment.governanceToken);
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), deployment.gameFiDAO);
        
        // Configure tournament system with advanced tokenomics
        TournamentSystem tournamentSystem = TournamentSystem(deployment.tournamentSystem);
        AdvancedTokenomics tokenomics = AdvancedTokenomics(deployment.advancedTokenomics);
        
        // Grant fee manager role to tournament system
        tokenomics.grantRole(tokenomics.FEE_MANAGER_ROLE(), address(tournamentSystem));
        
        // Configure AI Analytics with operator roles
        AIAnalyticsEngine analytics = AIAnalyticsEngine(deployment.aiAnalyticsEngine);
        analytics.grantRole(analytics.AI_OPERATOR_ROLE(), deployment.tournamentSystem);
        analytics.grantRole(analytics.AI_OPERATOR_ROLE(), deployment.socialGameFi);
        
        // Configure social system
        SocialGameFi social = SocialGameFi(deployment.socialGameFi);
        // Grant moderator roles (in production, this would be a multisig)
        social.grantRole(social.MODERATOR_ROLE(), msg.sender);
        
        console.log("Phase 3 configuration completed");
    }

    function _setupCrossChain(uint256 chainId) internal {
        console.log("Setting up cross-chain configurations for chain:", chainId);
        
        CrossChainBridge bridge = CrossChainBridge(deployment.crossChainBridge);
        
        // Configure supported chains
        if (chainId != 137) { // If not on Polygon, add Polygon support
            bridge.updateChainConfig(
                137, // Polygon
                true, // isActive
                3,    // minValidators
                0.001 ether, // bridgeFee
                address(0)   // bridgeContract (will be updated after deployment on Polygon)
            );
        }
        
        if (chainId != 42161) { // If not on Arbitrum, add Arbitrum support
            bridge.updateChainConfig(
                42161, // Arbitrum
                true, // isActive
                3,    // minValidators
                0.001 ether, // bridgeFee
                address(0)   // bridgeContract
            );
        }
        
        if (chainId != 324) { // If not on zkSync, add zkSync support
            bridge.updateChainConfig(
                324, // zkSync
                true, // isActive
                3,    // minValidators
                0.001 ether, // bridgeFee
                address(0)   // bridgeContract
            );
        }
        
        console.log("Cross-chain configuration completed");
    }

    function _logDeployment(NetworkConfig memory config) internal view {
        console.log("\n=== PHASE 3 DEPLOYMENT COMPLETE ===");
        console.log("Network:", config.name);
        console.log("Chain ID:", config.chainId);
        console.log("\nCore Contracts:");
        console.log("GameToken:", config.gameToken);
        console.log("GamePass:", config.gamePass);
        console.log("MonitoringSystem:", config.monitoringSystem);
        console.log("Treasury:", config.treasury);
        
        console.log("\nPhase 3 Contracts:");
        console.log("CrossChainBridge:", deployment.crossChainBridge);
        console.log("GovernanceToken:", deployment.governanceToken);
        console.log("GameFiDAO:", deployment.gameFiDAO);
        console.log("TournamentSystem:", deployment.tournamentSystem);
        console.log("AdvancedTokenomics:", deployment.advancedTokenomics);
        console.log("AIAnalyticsEngine:", deployment.aiAnalyticsEngine);
        console.log("SocialGameFi:", deployment.socialGameFi);
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Verify contracts on block explorer");
        console.log("2. Update frontend configuration with new addresses");
        console.log("3. Configure cross-chain validators");
        console.log("4. Setup initial DAO proposals");
        console.log("5. Launch community governance");
        console.log("6. Deploy mobile dApp");
        console.log("7. Enable AI analytics monitoring");
        console.log("8. Launch social features beta");
    }

    // Helper function to get deployment addresses
    function getDeploymentAddresses() external view returns (Phase3Deployment memory) {
        return deployment;
    }

    // Function to deploy on specific testnets
    function deployTestnet() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        NetworkConfig memory testConfig = NetworkConfig({
            chainId: block.chainid,
            name: "Local Testnet",
            gameToken: address(0),
            gamePass: address(0),
            monitoringSystem: address(0),
            treasury: msg.sender,
            isTestnet: true
        });
        
        _deployCore(testConfig);
        _deployPhase3(testConfig);
        _configurePhase3();
        
        vm.stopBroadcast();
        
        _logDeployment(testConfig);
    }

    // Function to setup validators for cross-chain bridge
    function setupBridgeValidators(address[] memory validators) external {
        require(deployment.crossChainBridge != address(0), "Bridge not deployed");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        CrossChainBridge bridge = CrossChainBridge(deployment.crossChainBridge);
        
        for (uint256 i = 0; i < validators.length; i++) {
            bridge.grantRole(bridge.VALIDATOR_ROLE(), validators[i]);
            console.log("Granted validator role to:", validators[i]);
        }
        
        vm.stopBroadcast();
        console.log("Bridge validators configured");
    }

    // Function to create initial DAO proposal
    function createInitialDAOProposal() external {
        require(deployment.gameFiDAO != address(0), "DAO not deployed");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        GameFiDAO dao = GameFiDAO(payable(deployment.gameFiDAO));
        GovernanceToken govToken = GovernanceToken(deployment.governanceToken);
        
        // Ensure deployer has enough tokens to propose
        require(govToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD, "Insufficient tokens to propose");
        
        // Create initial proposal to set up treasury allocation
        dao.propose(
            "Initial Treasury Setup",
            "Proposal to establish initial treasury allocation and operational parameters for the GameFi ecosystem",
            GameFiDAO.ProposalType.Treasury,
            deployment.advancedTokenomics,
            0,
            abi.encodeWithSignature("updateBuybackConfig(uint256,uint256,uint256,uint256,bool)", 1000, 100000 * 10**18, 86400, 5000, true)
        );
        
        vm.stopBroadcast();
        console.log("Initial DAO proposal created");
    }
}