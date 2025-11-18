// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IMonitoringSystem.sol";

/**
 * @title AdvancedTokenomics
 * @dev Enhanced tokenomics system with dynamic fees, loyalty programs, and automated buyback
 */
contract AdvancedTokenomics is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant TOKENOMICS_ADMIN_ROLE = keccak256("TOKENOMICS_ADMIN_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    enum UserTier {
        Bronze,   // 0-1000 tokens
        Silver,   // 1001-10000 tokens
        Gold,     // 10001-100000 tokens
        Platinum, // 100001-1000000 tokens
        Diamond   // 1000000+ tokens
    }

    struct LoyaltyProgram {
        uint256 minHoldingAmount;
        uint256 discountPercentage;    // Basis points (100 = 1%)
        uint256 bonusMultiplier;       // Basis points (10000 = 1x)
        uint256 stakingBonus;          // Additional staking rewards
        bool isActive;
    }

    struct UserLoyalty {
        UserTier tier;
        uint256 loyaltyPoints;
        uint256 totalSpent;
        uint256 joinTimestamp;
        uint256 lastActivityTimestamp;
        uint256 consecutiveDays;
        mapping(address => uint256) gameSpecificSpending;
    }

    struct FeeStructure {
        uint256 baseFee;               // Base fee in basis points
        uint256 volumeDiscountThreshold; // Threshold for volume discount
        uint256 volumeDiscountRate;    // Discount rate for high volume
        uint256 loyaltyDiscountCap;    // Maximum loyalty discount
        bool isDynamic;                // Whether fee adjusts based on activity
        uint256 lastAdjustment;        // Timestamp of last fee adjustment
    }

    struct BuybackConfig {
        uint256 triggerThreshold;      // Price drop threshold to trigger buyback
        uint256 maxBuybackAmount;      // Maximum tokens to buyback per session
        uint256 buybackFrequency;      // Minimum time between buybacks
        uint256 burnPercentage;        // Percentage of bought tokens to burn
        bool isActive;
        uint256 lastBuyback;
    }

    struct TokenMetrics {
        uint256 totalBurned;
        uint256 totalBuyback;
        uint256 circulatingSupply;
        uint256 priceImpactThreshold;
        uint256 lastPriceUpdate;
        uint256 currentPrice;
        uint256 averagePrice24h;
    }

    // State variables
    IERC20 public gameToken;
    IMonitoringSystem public monitoringSystem;
    
    mapping(UserTier => LoyaltyProgram) public loyaltyPrograms;
    mapping(address => UserLoyalty) public userLoyalty;
    mapping(address => FeeStructure) public gameContractFees; // Fees for different game contracts
    
    BuybackConfig public buybackConfig;
    TokenMetrics public tokenMetrics;
    
    address public treasury;
    address public liquidityPool;
    address public burnAddress = 0x000000000000000000000000000000000000dEaD;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DAILY_ACTIVITY_BONUS = 10; // 10 loyalty points per day
    uint256 public constant TIER_UPGRADE_THRESHOLD = 30; // 30 days consecutive activity

    // Price tracking
    uint256[] private priceHistory;
    uint256 public constant PRICE_HISTORY_LENGTH = 24; // 24 hour tracking

    // Events
    event UserTierUpgraded(address indexed user, UserTier oldTier, UserTier newTier);
    event LoyaltyPointsEarned(address indexed user, uint256 points, string reason);
    event FeeDiscountApplied(address indexed user, uint256 originalFee, uint256 discountedFee);
    event BuybackExecuted(uint256 amount, uint256 burnAmount, uint256 treasuryAmount);
    event TokensBurned(uint256 amount, string reason);
    event FeeStructureUpdated(address indexed gameContract, uint256 newBaseFee);
    event LoyaltyProgramUpdated(UserTier tier, uint256 minHolding, uint256 discount);

    modifier onlyTokenomicsAdmin() {
        require(hasRole(TOKENOMICS_ADMIN_ROLE, msg.sender), "Not tokenomics admin");
        _;
    }

    modifier onlyFeeManager() {
        require(hasRole(FEE_MANAGER_ROLE, msg.sender), "Not fee manager");
        _;
    }

    constructor(
        address _gameToken,
        address _treasury,
        address _liquidityPool,
        address _monitoringSystem
    ) {
        require(_gameToken != address(0), "Invalid game token");
        require(_treasury != address(0), "Invalid treasury");
        require(_liquidityPool != address(0), "Invalid liquidity pool");

        gameToken = IERC20(_gameToken);
        treasury = _treasury;
        liquidityPool = _liquidityPool;
        monitoringSystem = IMonitoringSystem(_monitoringSystem);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TOKENOMICS_ADMIN_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);

        _initializeLoyaltyPrograms();
        _initializeBuybackConfig();
    }

    /**
     * @dev Initialize loyalty program tiers
     */
    function _initializeLoyaltyPrograms() internal {
        loyaltyPrograms[UserTier.Bronze] = LoyaltyProgram({
            minHoldingAmount: 0,
            discountPercentage: 0,
            bonusMultiplier: 10000,
            stakingBonus: 0,
            isActive: true
        });

        loyaltyPrograms[UserTier.Silver] = LoyaltyProgram({
            minHoldingAmount: 1000 * 10**18,
            discountPercentage: 250, // 2.5%
            bonusMultiplier: 11000,  // 1.1x
            stakingBonus: 500,       // 5% additional staking
            isActive: true
        });

        loyaltyPrograms[UserTier.Gold] = LoyaltyProgram({
            minHoldingAmount: 10000 * 10**18,
            discountPercentage: 500, // 5%
            bonusMultiplier: 12500,  // 1.25x
            stakingBonus: 1000,      // 10% additional staking
            isActive: true
        });

        loyaltyPrograms[UserTier.Platinum] = LoyaltyProgram({
            minHoldingAmount: 100000 * 10**18,
            discountPercentage: 750,  // 7.5%
            bonusMultiplier: 15000,   // 1.5x
            stakingBonus: 1500,       // 15% additional staking
            isActive: true
        });

        loyaltyPrograms[UserTier.Diamond] = LoyaltyProgram({
            minHoldingAmount: 1000000 * 10**18,
            discountPercentage: 1000, // 10%
            bonusMultiplier: 20000,   // 2x
            stakingBonus: 2000,       // 20% additional staking
            isActive: true
        });
    }

    /**
     * @dev Initialize buyback configuration
     */
    function _initializeBuybackConfig() internal {
        buybackConfig = BuybackConfig({
            triggerThreshold: 1000,    // 10% price drop
            maxBuybackAmount: 100000 * 10**18,
            buybackFrequency: 86400,   // 24 hours
            burnPercentage: 5000,      // 50% burn, 50% to treasury
            isActive: true,
            lastBuyback: 0
        });
    }

    /**
     * @dev Calculate dynamic fee based on user tier and activity
     */
    function calculateDynamicFee(
        address user,
        address gameContract,
        uint256 baseAmount
    ) external view returns (uint256 finalFee, uint256 discount) {
        FeeStructure memory feeStructure = gameContractFees[gameContract];
        if (feeStructure.baseFee == 0) {
            return (0, 0);
        }

        uint256 originalFee = (baseAmount * feeStructure.baseFee) / BASIS_POINTS;
        uint256 totalDiscount = 0;

        UserLoyalty storage loyalty = userLoyalty[user];
        
        // Apply loyalty tier discount
        LoyaltyProgram memory program = loyaltyPrograms[loyalty.tier];
        if (program.isActive) {
            uint256 loyaltyDiscount = (originalFee * program.discountPercentage) / BASIS_POINTS;
            totalDiscount += loyaltyDiscount;
        }

        // Apply volume discount
        if (loyalty.totalSpent >= feeStructure.volumeDiscountThreshold) {
            uint256 volumeDiscount = (originalFee * feeStructure.volumeDiscountRate) / BASIS_POINTS;
            totalDiscount += volumeDiscount;
        }

        // Cap total discount
        if (totalDiscount > (originalFee * feeStructure.loyaltyDiscountCap) / BASIS_POINTS) {
            totalDiscount = (originalFee * feeStructure.loyaltyDiscountCap) / BASIS_POINTS;
        }

        uint256 finalFeeAmount = originalFee > totalDiscount ? originalFee - totalDiscount : 0;
        return (finalFeeAmount, totalDiscount);
    }

    /**
     * @dev Record user activity and update loyalty metrics
     */
    function recordUserActivity(
        address user,
        uint256 spentAmount,
        address gameContract
    ) external onlyFeeManager {
        UserLoyalty storage loyalty = userLoyalty[user];
        
        // Update spending
        loyalty.totalSpent += spentAmount;
        loyalty.gameSpecificSpending[gameContract] += spentAmount;
        
        // Update activity timestamp and consecutive days
        uint256 currentDay = block.timestamp / 86400;
        uint256 lastActivityDay = loyalty.lastActivityTimestamp / 86400;
        
        if (currentDay == lastActivityDay + 1) {
            loyalty.consecutiveDays++;
        } else if (currentDay > lastActivityDay + 1) {
            loyalty.consecutiveDays = 1;
        }
        
        loyalty.lastActivityTimestamp = block.timestamp;
        
        // Award daily activity bonus
        if (currentDay > lastActivityDay) {
            _awardLoyaltyPoints(user, DAILY_ACTIVITY_BONUS, "Daily activity");
        }
        
        // Check for tier upgrade
        _checkTierUpgrade(user);
    }

    /**
     * @dev Award loyalty points to user
     */
    function _awardLoyaltyPoints(address user, uint256 points, string memory reason) internal {
        UserLoyalty storage loyalty = userLoyalty[user];
        loyalty.loyaltyPoints += points;
        
        emit LoyaltyPointsEarned(user, points, reason);
    }

    /**
     * @dev Check and update user tier based on holdings and activity
     */
    function _checkTierUpgrade(address user) internal {
        UserLoyalty storage loyalty = userLoyalty[user];
        uint256 userBalance = gameToken.balanceOf(user);
        
        UserTier newTier = _calculateUserTier(userBalance, loyalty.consecutiveDays);
        
        if (newTier != loyalty.tier) {
            UserTier oldTier = loyalty.tier;
            loyalty.tier = newTier;
            emit UserTierUpgraded(user, oldTier, newTier);
        }
    }

    /**
     * @dev Calculate user tier based on token holdings and activity
     */
    function _calculateUserTier(uint256 balance, uint256 consecutiveDays) internal pure returns (UserTier) {
        if (balance >= 1000000 * 10**18 && consecutiveDays >= TIER_UPGRADE_THRESHOLD) {
            return UserTier.Diamond;
        } else if (balance >= 100000 * 10**18 && consecutiveDays >= TIER_UPGRADE_THRESHOLD) {
            return UserTier.Platinum;
        } else if (balance >= 10000 * 10**18 && consecutiveDays >= TIER_UPGRADE_THRESHOLD) {
            return UserTier.Gold;
        } else if (balance >= 1000 * 10**18 && consecutiveDays >= TIER_UPGRADE_THRESHOLD) {
            return UserTier.Silver;
        } else {
            return UserTier.Bronze;
        }
    }

    /**
     * @dev Execute automated buyback and burn mechanism
     */
    function executeBuyback() external nonReentrant {
        require(buybackConfig.isActive, "Buyback not active");
        require(
            block.timestamp >= buybackConfig.lastBuyback + buybackConfig.buybackFrequency,
            "Too frequent buyback"
        );
        
        // Check if price drop threshold is met
        require(_shouldTriggerBuyback(), "Buyback conditions not met");
        
        uint256 buybackAmount = buybackConfig.maxBuybackAmount;
        uint256 treasuryBalance = gameToken.balanceOf(treasury);
        
        if (buybackAmount > treasuryBalance) {
            buybackAmount = treasuryBalance;
        }
        
        if (buybackAmount > 0) {
            // Calculate burn and treasury amounts
            uint256 burnAmount = (buybackAmount * buybackConfig.burnPercentage) / BASIS_POINTS;
            uint256 treasuryAmount = buybackAmount - burnAmount;
            
            // Execute buyback
            if (burnAmount > 0) {
                require(gameToken.transferFrom(treasury, burnAddress, burnAmount), "Burn transfer failed");
                tokenMetrics.totalBurned += burnAmount;
            }
            
            if (treasuryAmount > 0) {
                require(gameToken.transferFrom(treasury, address(this), treasuryAmount), "Treasury transfer failed");
            }
            
            tokenMetrics.totalBuyback += buybackAmount;
            buybackConfig.lastBuyback = block.timestamp;
            
            emit BuybackExecuted(buybackAmount, burnAmount, treasuryAmount);
            emit TokensBurned(burnAmount, "Automated buyback burn");
        }
    }

    /**
     * @dev Check if buyback should be triggered based on price conditions
     */
    function _shouldTriggerBuyback() internal view returns (bool) {
        if (priceHistory.length < 2) return false;
        
        uint256 currentPrice = priceHistory[priceHistory.length - 1];
        uint256 averagePrice = _calculateAveragePrice();
        
        if (averagePrice == 0) return false;
        
        uint256 priceDropPercentage = ((averagePrice - currentPrice) * BASIS_POINTS) / averagePrice;
        return priceDropPercentage >= buybackConfig.triggerThreshold;
    }

    /**
     * @dev Calculate average price from recent history
     */
    function _calculateAveragePrice() internal view returns (uint256) {
        if (priceHistory.length == 0) return 0;
        
        uint256 sum = 0;
        uint256 length = priceHistory.length > PRICE_HISTORY_LENGTH ? PRICE_HISTORY_LENGTH : priceHistory.length;
        
        for (uint256 i = priceHistory.length - length; i < priceHistory.length; i++) {
            sum += priceHistory[i];
        }
        
        return sum / length;
    }

    /**
     * @dev Update token price (called by price oracle or admin)
     */
    function updateTokenPrice(uint256 newPrice) external onlyFeeManager {
        priceHistory.push(newPrice);
        
        // Maintain price history length
        if (priceHistory.length > PRICE_HISTORY_LENGTH) {
            for (uint256 i = 0; i < priceHistory.length - 1; i++) {
                priceHistory[i] = priceHistory[i + 1];
            }
            priceHistory.pop();
        }
        
        tokenMetrics.currentPrice = newPrice;
        tokenMetrics.averagePrice24h = _calculateAveragePrice();
        tokenMetrics.lastPriceUpdate = block.timestamp;
    }

    /**
     * @dev Set fee structure for a game contract
     */
    function setGameContractFee(
        address gameContract,
        uint256 baseFee,
        uint256 volumeDiscountThreshold,
        uint256 volumeDiscountRate,
        uint256 loyaltyDiscountCap,
        bool isDynamic
    ) external onlyTokenomicsAdmin {
        require(gameContract != address(0), "Invalid game contract");
        require(baseFee <= 1000, "Fee too high"); // Max 10%
        
        gameContractFees[gameContract] = FeeStructure({
            baseFee: baseFee,
            volumeDiscountThreshold: volumeDiscountThreshold,
            volumeDiscountRate: volumeDiscountRate,
            loyaltyDiscountCap: loyaltyDiscountCap,
            isDynamic: isDynamic,
            lastAdjustment: block.timestamp
        });
        
        emit FeeStructureUpdated(gameContract, baseFee);
    }

    /**
     * @dev Update loyalty program for a tier
     */
    function updateLoyaltyProgram(
        UserTier tier,
        uint256 minHoldingAmount,
        uint256 discountPercentage,
        uint256 bonusMultiplier,
        uint256 stakingBonus,
        bool isActive
    ) external onlyTokenomicsAdmin {
        loyaltyPrograms[tier] = LoyaltyProgram({
            minHoldingAmount: minHoldingAmount,
            discountPercentage: discountPercentage,
            bonusMultiplier: bonusMultiplier,
            stakingBonus: stakingBonus,
            isActive: isActive
        });
        
        emit LoyaltyProgramUpdated(tier, minHoldingAmount, discountPercentage);
    }

    /**
     * @dev Update buyback configuration
     */
    function updateBuybackConfig(
        uint256 triggerThreshold,
        uint256 maxBuybackAmount,
        uint256 buybackFrequency,
        uint256 burnPercentage,
        bool isActive
    ) external onlyTokenomicsAdmin {
        buybackConfig = BuybackConfig({
            triggerThreshold: triggerThreshold,
            maxBuybackAmount: maxBuybackAmount,
            buybackFrequency: buybackFrequency,
            burnPercentage: burnPercentage,
            isActive: isActive,
            lastBuyback: buybackConfig.lastBuyback
        });
    }

    /**
     * @dev Manual token burn (emergency function)
     */
    function emergencyBurn(uint256 amount, string memory reason) external onlyTokenomicsAdmin {
        require(gameToken.transferFrom(treasury, burnAddress, amount), "Burn failed");
        tokenMetrics.totalBurned += amount;
        emit TokensBurned(amount, reason);
    }

    // View functions
    function getUserTier(address user) external view returns (UserTier) {
        return userLoyalty[user].tier;
    }

    function getUserLoyaltyInfo(address user) external view returns (
        UserTier tier,
        uint256 loyaltyPoints,
        uint256 totalSpent,
        uint256 consecutiveDays
    ) {
        UserLoyalty storage loyalty = userLoyalty[user];
        return (loyalty.tier, loyalty.loyaltyPoints, loyalty.totalSpent, loyalty.consecutiveDays);
    }

    function getLoyaltyProgram(UserTier tier) external view returns (LoyaltyProgram memory) {
        return loyaltyPrograms[tier];
    }

    function getTokenMetrics() external view returns (TokenMetrics memory) {
        return tokenMetrics;
    }

    function getPriceHistory() external view returns (uint256[] memory) {
        return priceHistory;
    }
}