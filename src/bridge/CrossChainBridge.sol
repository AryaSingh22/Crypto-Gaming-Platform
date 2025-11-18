// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title CrossChainBridge
 * @dev Bridge contract for cross-chain GamePass NFT and GameToken transfers
 * Supports Polygon, Arbitrum, and zkSync networks
 */
contract CrossChainBridge is AccessControl, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;

    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    struct BridgeRequest {
        address user;
        address tokenContract;
        uint256 tokenId;
        uint256 chainId;
        uint256 nonce;
        bool isNFT;
        uint256 amount; // For ERC20 tokens
        bytes32 requestHash;
        bool processed;
    }

    struct ChainConfig {
        bool isActive;
        uint256 minValidators;
        uint256 bridgeFee;
        address bridgeContract;
    }

    // Supported chain IDs
    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    uint256 public constant ZKSYNC_CHAIN_ID = 324;
    uint256 public constant ETHEREUM_CHAIN_ID = 1;

    // State variables
    mapping(uint256 => ChainConfig) public chainConfigs;
    mapping(bytes32 => BridgeRequest) public bridgeRequests;
    mapping(bytes32 => mapping(address => bool)) public validatorSignatures;
    mapping(bytes32 => uint256) public signatureCount;
    mapping(address => uint256) public userNonces;

    // Events
    event BridgeRequestCreated(
        bytes32 indexed requestHash,
        address indexed user,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 targetChainId,
        bool isNFT,
        uint256 amount
    );

    event BridgeRequestProcessed(
        bytes32 indexed requestHash,
        address indexed user,
        uint256 targetChainId
    );

    event ValidatorSignatureAdded(
        bytes32 indexed requestHash,
        address indexed validator
    );

    event ChainConfigUpdated(
        uint256 indexed chainId,
        bool isActive,
        uint256 minValidators,
        uint256 bridgeFee
    );

    modifier validChain(uint256 chainId) {
        require(chainConfigs[chainId].isActive, "Chain not supported");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);

        // Initialize supported chains
        _initializeChainConfigs();
    }

    /**
     * @dev Initialize default chain configurations
     */
    function _initializeChainConfigs() internal {
        // Polygon configuration
        chainConfigs[POLYGON_CHAIN_ID] = ChainConfig({
            isActive: true,
            minValidators: 3,
            bridgeFee: 0.001 ether,
            bridgeContract: address(0)
        });

        // Arbitrum configuration
        chainConfigs[ARBITRUM_CHAIN_ID] = ChainConfig({
            isActive: true,
            minValidators: 3,
            bridgeFee: 0.001 ether,
            bridgeContract: address(0)
        });

        // zkSync configuration
        chainConfigs[ZKSYNC_CHAIN_ID] = ChainConfig({
            isActive: true,
            minValidators: 3,
            bridgeFee: 0.001 ether,
            bridgeContract: address(0)
        });
    }

    /**
     * @dev Create a bridge request to transfer NFT to another chain
     */
    function bridgeNFT(
        address tokenContract,
        uint256 tokenId,
        uint256 targetChainId
    ) external payable nonReentrant whenNotPaused validChain(targetChainId) {
        require(targetChainId != block.chainid, "Cannot bridge to same chain");
        require(msg.value >= chainConfigs[targetChainId].bridgeFee, "Insufficient bridge fee");

        // Verify NFT ownership
        IERC721 nft = IERC721(tokenContract);
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");

        // Transfer NFT to bridge contract
        nft.transferFrom(msg.sender, address(this), tokenId);

        // Create bridge request
        uint256 nonce = userNonces[msg.sender]++;
        bytes32 requestHash = keccak256(abi.encodePacked(
            msg.sender,
            tokenContract,
            tokenId,
            targetChainId,
            nonce,
            block.chainid,
            true // isNFT
        ));

        bridgeRequests[requestHash] = BridgeRequest({
            user: msg.sender,
            tokenContract: tokenContract,
            tokenId: tokenId,
            chainId: targetChainId,
            nonce: nonce,
            isNFT: true,
            amount: 0,
            requestHash: requestHash,
            processed: false
        });

        emit BridgeRequestCreated(
            requestHash,
            msg.sender,
            tokenContract,
            tokenId,
            targetChainId,
            true,
            0
        );
    }

    /**
     * @dev Create a bridge request to transfer tokens to another chain
     */
    function bridgeToken(
        address tokenContract,
        uint256 amount,
        uint256 targetChainId
    ) external payable nonReentrant whenNotPaused validChain(targetChainId) {
        require(targetChainId != block.chainid, "Cannot bridge to same chain");
        require(amount > 0, "Amount must be greater than 0");
        require(msg.value >= chainConfigs[targetChainId].bridgeFee, "Insufficient bridge fee");

        // Transfer tokens to bridge contract
        IERC20 token = IERC20(tokenContract);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        // Create bridge request
        uint256 nonce = userNonces[msg.sender]++;
        bytes32 requestHash = keccak256(abi.encodePacked(
            msg.sender,
            tokenContract,
            uint256(0), // tokenId not used for ERC20
            targetChainId,
            nonce,
            block.chainid,
            false, // isNFT
            amount
        ));

        bridgeRequests[requestHash] = BridgeRequest({
            user: msg.sender,
            tokenContract: tokenContract,
            tokenId: 0,
            chainId: targetChainId,
            nonce: nonce,
            isNFT: false,
            amount: amount,
            requestHash: requestHash,
            processed: false
        });

        emit BridgeRequestCreated(
            requestHash,
            msg.sender,
            tokenContract,
            0,
            targetChainId,
            false,
            amount
        );
    }

    /**
     * @dev Validators sign bridge requests to approve cross-chain transfers
     */
    function signBridgeRequest(
        bytes32 requestHash,
        bytes calldata signature
    ) external onlyRole(VALIDATOR_ROLE) {
        require(bridgeRequests[requestHash].user != address(0), "Request does not exist");
        require(!bridgeRequests[requestHash].processed, "Request already processed");
        require(!validatorSignatures[requestHash][msg.sender], "Already signed");

        // Verify signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            requestHash
        ));
        address signer = messageHash.recover(signature);
        require(hasRole(VALIDATOR_ROLE, signer), "Invalid validator signature");

        validatorSignatures[requestHash][msg.sender] = true;
        signatureCount[requestHash]++;

        emit ValidatorSignatureAdded(requestHash, msg.sender);

        // Check if we have enough signatures to process
        BridgeRequest storage request = bridgeRequests[requestHash];
        if (signatureCount[requestHash] >= chainConfigs[request.chainId].minValidators) {
            _processBridgeRequest(requestHash);
        }
    }

    /**
     * @dev Process bridge request once enough validator signatures are collected
     */
    function _processBridgeRequest(bytes32 requestHash) internal {
        BridgeRequest storage request = bridgeRequests[requestHash];
        require(!request.processed, "Request already processed");

        request.processed = true;

        emit BridgeRequestProcessed(
            requestHash,
            request.user,
            request.chainId
        );
    }

    /**
     * @dev Release bridged assets back to user (called by validators on target chain)
     */
    function releaseBridgedAsset(
        address user,
        address tokenContract,
        uint256 tokenId,
        bool isNFT,
        uint256 amount,
        bytes32 /*originalRequestHash*/
    ) external onlyRole(VALIDATOR_ROLE) nonReentrant {
        if (isNFT) {
            IERC721(tokenContract).transferFrom(address(this), user, tokenId);
        } else {
            require(IERC20(tokenContract).transfer(user, amount), "Token transfer failed");
        }
    }

    /**
     * @dev Update chain configuration
     */
    function updateChainConfig(
        uint256 chainId,
        bool isActive,
        uint256 minValidators,
        uint256 bridgeFee,
        address bridgeContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        chainConfigs[chainId] = ChainConfig({
            isActive: isActive,
            minValidators: minValidators,
            bridgeFee: bridgeFee,
            bridgeContract: bridgeContract
        });

        emit ChainConfigUpdated(chainId, isActive, minValidators, bridgeFee);
    }

    /**
     * @dev Withdraw collected bridge fees
     */
    function withdrawFees(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid address");
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Emergency pause function
     */
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause function
     */
    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    /**
     * @dev Get bridge request details
     */
    function getBridgeRequest(bytes32 requestHash) external view returns (BridgeRequest memory) {
        return bridgeRequests[requestHash];
    }

    /**
     * @dev Check if validator has signed a request
     */
    function hasValidatorSigned(bytes32 requestHash, address validator) external view returns (bool) {
        return validatorSignatures[requestHash][validator];
    }

    /**
     * @dev Get signature count for a request
     */
    function getSignatureCount(bytes32 requestHash) external view returns (uint256) {
        return signatureCount[requestHash];
    }
}