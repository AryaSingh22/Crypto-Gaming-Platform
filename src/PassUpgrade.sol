// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GamePass.sol";
import "./StakingPool.sol";

/**
 * @title PassUpgrade
 * @notice Contract for upgrading GamePass NFTs through staking and burning
 * @dev Allows Bronze → Silver → Gold progression via token staking or NFT burning
 */
contract PassUpgrade is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for upgrade administration
    bytes32 public constant UPGRADE_ADMIN_ROLE = keccak256("UPGRADE_ADMIN_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Game token for upgrade costs
    IERC20 public immutable gameToken;

    /// @notice GamePass NFT contract
    GamePass public immutable gamePass;

    /// @notice Staking pool for stake-based upgrades
    StakingPool public immutable stakingPool;

    /// @notice Treasury for collecting upgrade fees
    address public treasury;

    /// @notice Upgrade methods
    enum UpgradeMethod {
        TokenBurn,    // Burn GAME tokens
        StakeTime,    // Stake tokens for time period
        NFTBurn       // Burn lower tier NFTs
    }

    /// @notice Upgrade path configuration
    struct UpgradePath {
        GamePass.Tier fromTier;
        GamePass.Tier toTier;
        UpgradeMethod method;
        uint256 cost;           // Token cost or stake amount
        uint256 duration;       // Stake duration (for StakeTime method)
        uint256 burnCount;      // Number of NFTs to burn (for NFTBurn method)
        bool active;
    }

    /// @notice Available upgrade paths
    mapping(uint256 => UpgradePath) public upgradePaths;
    
    /// @notice Number of upgrade paths
    uint256 public upgradePathCount;

    /// @notice Pending staking upgrades
    struct PendingUpgrade {
        address user;
        uint256 tokenId;
        GamePass.Tier targetTier;
        uint256 stakePositionId;
        uint256 completionTime;
        bool completed;
    }

    /// @notice Mapping from upgrade ID to pending upgrade
    mapping(uint256 => PendingUpgrade) public pendingUpgrades;
    
    /// @notice Next upgrade ID
    uint256 public nextUpgradeId;

    /// @notice Mapping from user to pending upgrade IDs
    mapping(address => uint256[]) public userPendingUpgrades;

    /// @notice Mapping to track if token is being upgraded
    mapping(uint256 => bool) public tokenBeingUpgraded;

    /// @notice Events
    event UpgradePathAdded(
        uint256 indexed pathId,
        GamePass.Tier fromTier,
        GamePass.Tier toTier,
        UpgradeMethod method,
        uint256 cost
    );
    
    event UpgradeStarted(
        uint256 indexed upgradeId,
        address indexed user,
        uint256 indexed tokenId,
        GamePass.Tier fromTier,
        GamePass.Tier toTier,
        UpgradeMethod method
    );
    
    event UpgradeCompleted(
        uint256 indexed upgradeId,
        address indexed user,
        uint256 indexed tokenId,
        GamePass.Tier newTier
    );
    
    event InstantUpgrade(
        address indexed user,
        uint256 indexed tokenId,
        GamePass.Tier fromTier,
        GamePass.Tier toTier,
        uint256 cost
    );

    /// @notice Custom errors
    error InvalidUpgradePath();
    error TokenNotOwned();
    error InvalidTier();
    error TokenBeingUpgraded();
    error UpgradeNotFound();
    error UpgradeNotReady();
    error UpgradeAlreadyCompleted();
    error InsufficientNFTs();
    error ZeroAddress();

    /**
     * @notice Constructor
     * @param gameTokenAddress Game token address
     * @param gamePassAddress GamePass address
     * @param stakingPoolAddress StakingPool address
     * @param treasuryAddress Treasury address
     * @param admin Admin address
     */
    constructor(
        address gameTokenAddress,
        address gamePassAddress,
        address stakingPoolAddress,
        address treasuryAddress,
        address admin
    ) {
        if (
            gameTokenAddress == address(0) ||
            gamePassAddress == address(0) ||
            stakingPoolAddress == address(0) ||
            treasuryAddress == address(0) ||
            admin == address(0)
        ) revert ZeroAddress();

        gameToken = IERC20(gameTokenAddress);
        gamePass = GamePass(gamePassAddress);
        stakingPool = StakingPool(stakingPoolAddress);
        treasury = treasuryAddress;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADE_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Initialize default upgrade paths
        _initializeUpgradePaths();

        // Start upgrade IDs at 1
        nextUpgradeId = 1;
    }

    /**
     * @notice Instant upgrade by burning tokens
     * @param tokenId Token ID to upgrade
     * @param pathId Upgrade path ID
     */
    function instantUpgrade(uint256 tokenId, uint256 pathId) external whenNotPaused nonReentrant {
        if (gamePass.ownerOf(tokenId) != msg.sender) revert TokenNotOwned();
        if (tokenBeingUpgraded[tokenId]) revert TokenBeingUpgraded();
        if (pathId >= upgradePathCount) revert InvalidUpgradePath();

        UpgradePath storage path = upgradePaths[pathId];
        if (!path.active || path.method != UpgradeMethod.TokenBurn) revert InvalidUpgradePath();

        GamePass.Tier currentTier = gamePass.tierOf(tokenId);
        if (currentTier != path.fromTier) revert InvalidTier();

        // Burn tokens for upgrade
        gameToken.safeTransferFrom(msg.sender, treasury, path.cost);

        // Upgrade the NFT (requires admin approval to call GamePass mint/burn)
        // This is a simplified version - in practice, you'd need a more sophisticated upgrade mechanism
        _executeUpgrade(tokenId, path.toTier);

        emit InstantUpgrade(msg.sender, tokenId, path.fromTier, path.toTier, path.cost);
    }

    /**
     * @notice Start stake-based upgrade
     * @param tokenId Token ID to upgrade
     * @param pathId Upgrade path ID
     */
    function startStakeUpgrade(uint256 tokenId, uint256 pathId) external whenNotPaused nonReentrant {
        if (gamePass.ownerOf(tokenId) != msg.sender) revert TokenNotOwned();
        if (tokenBeingUpgraded[tokenId]) revert TokenBeingUpgraded();
        if (pathId >= upgradePathCount) revert InvalidUpgradePath();

        UpgradePath storage path = upgradePaths[pathId];
        if (!path.active || path.method != UpgradeMethod.StakeTime) revert InvalidUpgradePath();

        GamePass.Tier currentTier = gamePass.tierOf(tokenId);
        if (currentTier != path.fromTier) revert InvalidTier();

        // Approve and stake tokens
        gameToken.safeTransferFrom(msg.sender, address(this), path.cost);
        gameToken.approve(address(stakingPool), path.cost);
        
        // Find appropriate lock period for upgrade duration
        // uint256 lockPeriodId = _findLockPeriod(path.duration);
        
        // This would need to be called by this contract to stake on behalf of user
        // stakingPool.stake(path.cost, lockPeriodId);

        uint256 upgradeId = nextUpgradeId++;
        
        pendingUpgrades[upgradeId] = PendingUpgrade({
            user: msg.sender,
            tokenId: tokenId,
            targetTier: path.toTier,
            stakePositionId: 0, // Would be returned from stake call
            completionTime: block.timestamp + path.duration,
            completed: false
        });

        userPendingUpgrades[msg.sender].push(upgradeId);
        tokenBeingUpgraded[tokenId] = true;

        emit UpgradeStarted(upgradeId, msg.sender, tokenId, path.fromTier, path.toTier, path.method);
    }

    /**
     * @notice Complete stake-based upgrade
     * @param upgradeId Upgrade ID
     */
    function completeStakeUpgrade(uint256 upgradeId) external nonReentrant {
        PendingUpgrade storage upgrade = pendingUpgrades[upgradeId];
        
        if (upgrade.user == address(0)) revert UpgradeNotFound();
        if (upgrade.user != msg.sender) revert TokenNotOwned();
        if (upgrade.completed) revert UpgradeAlreadyCompleted();
        if (block.timestamp < upgrade.completionTime) revert UpgradeNotReady();

        upgrade.completed = true;
        tokenBeingUpgraded[upgrade.tokenId] = false;

        // Execute the upgrade
        _executeUpgrade(upgrade.tokenId, upgrade.targetTier);

        emit UpgradeCompleted(upgradeId, msg.sender, upgrade.tokenId, upgrade.targetTier);
    }

    /**
     * @notice Upgrade by burning multiple lower tier NFTs
     * @param tokenIds Array of token IDs to burn
     * @param pathId Upgrade path ID
     */
    function upgradeByBurning(uint256[] calldata tokenIds, uint256 pathId) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        if (pathId >= upgradePathCount) revert InvalidUpgradePath();

        UpgradePath storage path = upgradePaths[pathId];
        if (!path.active || path.method != UpgradeMethod.NFTBurn) revert InvalidUpgradePath();
        if (tokenIds.length != path.burnCount) revert InsufficientNFTs();

        // Verify ownership and tier of all tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (gamePass.ownerOf(tokenIds[i]) != msg.sender) revert TokenNotOwned();
            if (tokenBeingUpgraded[tokenIds[i]]) revert TokenBeingUpgraded();
            
            GamePass.Tier tier = gamePass.tierOf(tokenIds[i]);
            if (tier != path.fromTier) revert InvalidTier();
        }

        // Choose the first token to upgrade, burn the rest
        uint256 upgradeTokenId = tokenIds[0];
        
        // Burn other tokens (this would require GamePass to have a burn function)
        for (uint256 i = 1; i < tokenIds.length; i++) {
            // gamePass.burn(tokenIds[i]); // Would need burn function in GamePass
        }

        // Execute upgrade on the remaining token
        _executeUpgrade(upgradeTokenId, path.toTier);

        emit InstantUpgrade(msg.sender, upgradeTokenId, path.fromTier, path.toTier, 0);
    }

    /**
     * @notice Add or update upgrade path
     * @param pathId Path ID
     * @param fromTier Source tier
     * @param toTier Target tier
     * @param method Upgrade method
     * @param cost Cost in tokens
     * @param duration Duration for stake method
     * @param burnCount Number of NFTs to burn
     * @param active Whether path is active
     */
    function setUpgradePath(
        uint256 pathId,
        GamePass.Tier fromTier,
        GamePass.Tier toTier,
        UpgradeMethod method,
        uint256 cost,
        uint256 duration,
        uint256 burnCount,
        bool active
    ) external onlyRole(UPGRADE_ADMIN_ROLE) {
        upgradePaths[pathId] = UpgradePath({
            fromTier: fromTier,
            toTier: toTier,
            method: method,
            cost: cost,
            duration: duration,
            burnCount: burnCount,
            active: active
        });

        if (pathId >= upgradePathCount) {
            upgradePathCount = pathId + 1;
        }

        emit UpgradePathAdded(pathId, fromTier, toTier, method, cost);
    }

    /**
     * @notice Set treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Get user's pending upgrades
     * @param user User address
     * @return Array of pending upgrade IDs
     */
    function getUserPendingUpgrades(address user) external view returns (uint256[] memory) {
        return userPendingUpgrades[user];
    }

    /**
     * @notice Get available upgrade paths for a tier
     * @param tier Source tier
     * @return Array of path IDs
     */
    function getUpgradePathsForTier(GamePass.Tier tier) external view returns (uint256[] memory) {
        uint256[] memory paths = new uint256[](upgradePathCount);
        uint256 count = 0;
        
        for (uint256 i = 0; i < upgradePathCount; i++) {
            if (upgradePaths[i].fromTier == tier && upgradePaths[i].active) {
                paths[count] = i;
                count++;
            }
        }
        
        // Resize array
        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = paths[i];
        }
        
        return result;
    }

    /**
     * @notice Initialize default upgrade paths
     */
    function _initializeUpgradePaths() internal {
        // Bronze → Silver via token burn
        upgradePaths[0] = UpgradePath({
            fromTier: GamePass.Tier.Bronze,
            toTier: GamePass.Tier.Silver,
            method: UpgradeMethod.TokenBurn,
            cost: 1000e18, // 1000 GAME
            duration: 0,
            burnCount: 0,
            active: true
        });

        // Silver → Gold via token burn
        upgradePaths[1] = UpgradePath({
            fromTier: GamePass.Tier.Silver,
            toTier: GamePass.Tier.Gold,
            method: UpgradeMethod.TokenBurn,
            cost: 5000e18, // 5000 GAME
            duration: 0,
            burnCount: 0,
            active: true
        });

        // Bronze → Silver via staking
        upgradePaths[2] = UpgradePath({
            fromTier: GamePass.Tier.Bronze,
            toTier: GamePass.Tier.Silver,
            method: UpgradeMethod.StakeTime,
            cost: 2000e18, // 2000 GAME staked
            duration: 30 days,
            burnCount: 0,
            active: true
        });

        // Silver → Gold via staking
        upgradePaths[3] = UpgradePath({
            fromTier: GamePass.Tier.Silver,
            toTier: GamePass.Tier.Gold,
            method: UpgradeMethod.StakeTime,
            cost: 10000e18, // 10000 GAME staked
            duration: 90 days,
            burnCount: 0,
            active: true
        });

        // Bronze → Silver via NFT burning (3 Bronze → 1 Silver)
        upgradePaths[4] = UpgradePath({
            fromTier: GamePass.Tier.Bronze,
            toTier: GamePass.Tier.Silver,
            method: UpgradeMethod.NFTBurn,
            cost: 0,
            duration: 0,
            burnCount: 3,
            active: true
        });

        upgradePathCount = 5;
    }

    /**
     * @notice Execute NFT upgrade (simplified - would need proper implementation)
     * @param tokenId Token ID to upgrade
     * @param newTier New tier
     */
    function _executeUpgrade(uint256 tokenId, GamePass.Tier newTier) internal {
        // This is a simplified version. In practice, you'd need:
        // 1. A burn function in GamePass
        // 2. Ability to mint specific tiers
        // 3. Proper metadata updates
        
        // For now, this would require admin intervention or
        // GamePass contract modifications to support upgrades
        
        // Pseudo-code:
        // gamePass.upgradeTier(tokenId, newTier);
    }

    /**
     * @notice Find appropriate lock period for duration
     * @param duration Required duration
     * @return Lock period ID
     */
    function _findLockPeriod(uint256 duration) internal pure returns (uint256) {
        if (duration <= 30 days) return 1;      // 30 days
        if (duration <= 90 days) return 2;      // 90 days
        if (duration <= 180 days) return 3;     // 180 days
        return 4;                               // 365 days
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}