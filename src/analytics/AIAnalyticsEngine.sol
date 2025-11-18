// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IMonitoringSystem.sol";

/**
 * @title AIAnalyticsEngine
 * @dev Advanced AI-powered analytics system for fraud detection, bot prevention, and personalized insights
 */
contract AIAnalyticsEngine is AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant AI_OPERATOR_ROLE = keccak256("AI_OPERATOR_ROLE");
    bytes32 public constant FRAUD_INVESTIGATOR_ROLE = keccak256("FRAUD_INVESTIGATOR_ROLE");
    bytes32 public constant ANALYTICS_ADMIN_ROLE = keccak256("ANALYTICS_ADMIN_ROLE");

    enum RiskLevel {
        Low,
        Medium,
        High,
        Critical
    }

    enum ActionType {
        GamePlay,
        Transaction,
        Staking,
        Trading,
        Social
    }

    enum FraudType {
        BotActivity,
        MultipleAccounts,
        SuspiciousPatterns,
        MarketManipulation,
        Collusion
    }

    struct UserBehaviorPattern {
        address user;
        uint256 totalActions;
        uint256 suspiciousActions;
        uint256 avgSessionDuration;
        uint256 avgTimeBetweenActions;
        uint256 winRate;
        uint256 lastActiveTimestamp;
        mapping(ActionType => uint256) actionCounts;
        mapping(uint256 => uint256) hourlyActivity; // hour -> action count
        uint256[] recentActionTimestamps;
        bool isBot;
        RiskLevel riskLevel;
        uint256 riskScore;
    }

    struct FraudAlert {
        uint256 id;
        address user;
        FraudType fraudType;
        RiskLevel severity;
        string description;
        uint256 timestamp;
        bool investigated;
        bool resolved;
        string resolution;
        address investigator;
    }

    struct PersonalizedInsight {
        address user;
        string category;
        string insight;
        uint256 confidence;
        string recommendation;
        uint256 timestamp;
        bool actionTaken;
    }

    struct AnalyticsConfig {
        uint256 botDetectionThreshold;      // Actions per minute threshold
        uint256 suspiciousPatternThreshold; // Percentage of suspicious actions
        uint256 collisionDetectionWindow;   // Time window for pattern analysis
        uint256 minSessionsForAnalysis;     // Minimum sessions before analysis
        bool aiEngineActive;
        uint256 riskScoreThreshold;
        uint256 insightGenerationInterval;
    }

    // State variables
    IMonitoringSystem public monitoringSystem;
    
    mapping(address => UserBehaviorPattern) public userBehaviors;
    mapping(uint256 => FraudAlert) public fraudAlerts;
    mapping(address => PersonalizedInsight[]) public userInsights;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;
    
    uint256 public fraudAlertCount;
    AnalyticsConfig public analyticsConfig;
    
    address[] public suspiciousUsers;
    address[] public verifiedUsers;
    
    // Machine learning model parameters (simplified on-chain implementation)
    struct MLModel {
        uint256[] weights;
        uint256 bias;
        uint256 threshold;
        uint256 accuracy;
        uint256 lastTraining;
        bool isActive;
    }
    
    mapping(string => MLModel) public mlModels;
    
    // Events
    event BotDetected(address indexed user, uint256 riskScore, string evidence);
    event FraudAlertCreated(uint256 indexed alertId, address indexed user, FraudType fraudType);
    event UserRiskUpdated(address indexed user, RiskLevel oldLevel, RiskLevel newLevel);
    event InsightGenerated(address indexed user, string category, string insight);
    event ModelUpdated(string modelName, uint256 accuracy);
    event UserBehaviorAnalyzed(address indexed user, uint256 riskScore, bool isBot);

    modifier onlyAIOperator() {
        require(hasRole(AI_OPERATOR_ROLE, msg.sender), "Not AI operator");
        _;
    }

    modifier onlyFraudInvestigator() {
        require(hasRole(FRAUD_INVESTIGATOR_ROLE, msg.sender), "Not fraud investigator");
        _;
    }

    constructor(address _monitoringSystem) {
        require(_monitoringSystem != address(0), "Invalid monitoring system");
        
        monitoringSystem = IMonitoringSystem(_monitoringSystem);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AI_OPERATOR_ROLE, msg.sender);
        _grantRole(FRAUD_INVESTIGATOR_ROLE, msg.sender);
        _grantRole(ANALYTICS_ADMIN_ROLE, msg.sender);
        
        _initializeAnalyticsConfig();
        _initializeMLModels();
    }

    /**
     * @dev Initialize analytics configuration
     */
    function _initializeAnalyticsConfig() internal {
        analyticsConfig = AnalyticsConfig({
            botDetectionThreshold: 60,      // 60 actions per minute
            suspiciousPatternThreshold: 80, // 80% suspicious actions
            collisionDetectionWindow: 3600, // 1 hour window
            minSessionsForAnalysis: 10,     // 10 sessions minimum
            aiEngineActive: true,
            riskScoreThreshold: 75,         // 75/100 risk score threshold
            insightGenerationInterval: 86400 // 24 hours
        });
    }

    /**
     * @dev Initialize machine learning models
     */
    function _initializeMLModels() internal {
        // Bot detection model
        uint256[] memory botWeights = new uint256[](5);
        botWeights[0] = 300; // Action frequency weight
        botWeights[1] = 250; // Pattern regularity weight
        botWeights[2] = 200; // Win rate consistency weight
        botWeights[3] = 150; // Session duration weight
        botWeights[4] = 100; // Social interaction weight
        
        mlModels["bot_detection"] = MLModel({
            weights: botWeights,
            bias: 100,
            threshold: 700,
            accuracy: 85,
            lastTraining: block.timestamp,
            isActive: true
        });
        
        // Fraud detection model
        uint256[] memory fraudWeights = new uint256[](4);
        fraudWeights[0] = 400; // Transaction pattern weight
        fraudWeights[1] = 300; // Account age weight
        fraudWeights[2] = 200; // Network analysis weight
        fraudWeights[3] = 100; // Behavior consistency weight
        
        mlModels["fraud_detection"] = MLModel({
            weights: fraudWeights,
            bias: 50,
            threshold: 600,
            accuracy: 90,
            lastTraining: block.timestamp,
            isActive: true
        });
    }

    /**
     * @dev Record user action for behavioral analysis
     */
    function recordUserAction(
        address user,
        ActionType actionType,
        uint256 /*value*/,
        bytes memory /*metadata*/
    ) external onlyAIOperator {
        require(!isBlacklisted[user], "User is blacklisted");
        
        UserBehaviorPattern storage behavior = userBehaviors[user];
        behavior.user = user;
        behavior.totalActions++;
        behavior.actionCounts[actionType]++;
        behavior.lastActiveTimestamp = block.timestamp;
        
        // Track recent actions for pattern analysis
        behavior.recentActionTimestamps.push(block.timestamp);
        if (behavior.recentActionTimestamps.length > 100) {
            // Keep only last 100 actions
            for (uint256 i = 0; i < 99; i++) {
                behavior.recentActionTimestamps[i] = behavior.recentActionTimestamps[i + 1];
            }
            behavior.recentActionTimestamps.pop();
        }
        
        // Update hourly activity
        uint256 currentHour = (block.timestamp / 3600) % 24;
        behavior.hourlyActivity[currentHour]++;
        
        // Trigger real-time analysis
        if (analyticsConfig.aiEngineActive && behavior.totalActions >= analyticsConfig.minSessionsForAnalysis) {
            _analyzeUserBehavior(user);
        }
    }

    /**
     * @dev Analyze user behavior for bot detection and fraud patterns
     */
    function _analyzeUserBehavior(address user) internal {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        
        uint256 riskScore = _calculateRiskScore(user);
        behavior.riskScore = riskScore;
        
        RiskLevel oldRiskLevel = behavior.riskLevel;
        RiskLevel newRiskLevel = _determineRiskLevel(riskScore);
        behavior.riskLevel = newRiskLevel;
        
        // Bot detection
        bool isBot = _detectBot(user);
        if (isBot && !behavior.isBot) {
            behavior.isBot = true;
            _createFraudAlert(user, FraudType.BotActivity, RiskLevel.High, "Bot-like behavior detected");
            emit BotDetected(user, riskScore, "Automated pattern recognition");
        }
        
        // Create fraud alerts for high-risk users
        if (riskScore >= analyticsConfig.riskScoreThreshold && !isWhitelisted[user]) {
            _createFraudAlert(user, FraudType.SuspiciousPatterns, newRiskLevel, "High risk score detected");
        }
        
        if (oldRiskLevel != newRiskLevel) {
            emit UserRiskUpdated(user, oldRiskLevel, newRiskLevel);
        }
        
        emit UserBehaviorAnalyzed(user, riskScore, isBot);
    }

    /**
     * @dev Calculate risk score using ML model
     */
    function _calculateRiskScore(address user) internal view returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        
        if (behavior.totalActions == 0) return 0;
        
        // Feature extraction
        uint256 actionFrequency = _calculateActionFrequency(user);
        uint256 patternRegularity = _calculatePatternRegularity(user);
        uint256 winRateConsistency = _calculateWinRateConsistency(user);
        uint256 sessionDurationScore = _calculateSessionDurationScore(user);
        // uint256 socialInteractionScore = _calculateSocialInteractionScore(user); // Commented out unused variable
        
        // Apply ML model weights
        MLModel storage model = mlModels["fraud_detection"];
        if (!model.isActive) return 0;
        
        uint256 weightedScore = 
            (actionFrequency * model.weights[0]) +
            (patternRegularity * model.weights[1]) +
            (winRateConsistency * model.weights[2]) +
            (sessionDurationScore * model.weights[3]);
        
        uint256 finalScore = (weightedScore / 1000) + model.bias;
        return finalScore > 100 ? 100 : finalScore;
    }

    /**
     * @dev Detect bot behavior patterns
     */
    function _detectBot(address user) internal view returns (bool) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        
        // Check action frequency
        uint256 actionFrequency = _calculateActionFrequency(user);
        if (actionFrequency > analyticsConfig.botDetectionThreshold) {
            return true;
        }
        
        // Check pattern regularity
        uint256 patternRegularity = _calculatePatternRegularity(user);
        if (patternRegularity > 90) { // Very regular patterns (90%+)
            return true;
        }
        
        // Check for inhuman consistency
        if (behavior.winRate > 95 && behavior.totalActions > 100) {
            return true;
        }
        
        return false;
    }

    /**
     * @dev Calculate action frequency (actions per minute)
     */
    function _calculateActionFrequency(address user) internal view returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        if (behavior.recentActionTimestamps.length < 2) return 0;
        
        uint256 timeSpan = behavior.recentActionTimestamps[behavior.recentActionTimestamps.length - 1] - 
                           behavior.recentActionTimestamps[0];
        
        if (timeSpan == 0) return 0;
        
        return (behavior.recentActionTimestamps.length * 60) / timeSpan;
    }

    /**
     * @dev Calculate pattern regularity score
     */
    function _calculatePatternRegularity(address user) internal view returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        if (behavior.recentActionTimestamps.length < 10) return 0;
        
        uint256 totalVariance = 0;
        uint256 avgInterval = 0;
        
        // Calculate average interval
        for (uint256 i = 1; i < behavior.recentActionTimestamps.length; i++) {
            avgInterval += behavior.recentActionTimestamps[i] - behavior.recentActionTimestamps[i-1];
        }
        avgInterval /= (behavior.recentActionTimestamps.length - 1);
        
        // Calculate variance
        for (uint256 i = 1; i < behavior.recentActionTimestamps.length; i++) {
            uint256 interval = behavior.recentActionTimestamps[i] - behavior.recentActionTimestamps[i-1];
            uint256 diff = interval > avgInterval ? interval - avgInterval : avgInterval - interval;
            totalVariance += diff;
        }
        
        uint256 variance = totalVariance / (behavior.recentActionTimestamps.length - 1);
        
        // Lower variance = higher regularity (inverted scale)
        return variance > avgInterval ? 0 : 100 - ((variance * 100) / avgInterval);
    }

    /**
     * @dev Calculate win rate consistency score
     */
    function _calculateWinRateConsistency(address user) internal view returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        
        // Simplified calculation - in real implementation, this would analyze
        // win rate variations across different time periods
        if (behavior.winRate > 80 || behavior.winRate < 20) {
            return 80; // Extreme win rates are suspicious
        }
        
        return 20; // Normal win rates
    }

    /**
     * @dev Calculate session duration score
     */
    function _calculateSessionDurationScore(address user) internal view returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        
        // Very short or very long sessions can be suspicious
        if (behavior.avgSessionDuration < 60 || behavior.avgSessionDuration > 14400) { // < 1 min or > 4 hours
            return 60;
        }
        
        return 20;
    }

    /**
     * @dev Calculate social interaction score
     */
    function _calculateSocialInteractionScore(address user) internal pure returns (uint256) {
        // This would analyze social interactions, chat messages, etc.
        // Simplified for this implementation
        user; // Silence unused parameter warning
        return 30;
    }

    /**
     * @dev Determine risk level from risk score
     */
    function _determineRiskLevel(uint256 riskScore) internal pure returns (RiskLevel) {
        if (riskScore >= 85) return RiskLevel.Critical;
        if (riskScore >= 70) return RiskLevel.High;
        if (riskScore >= 40) return RiskLevel.Medium;
        return RiskLevel.Low;
    }

    /**
     * @dev Create fraud alert
     */
    function _createFraudAlert(
        address user,
        FraudType fraudType,
        RiskLevel severity,
        string memory description
    ) internal {
        uint256 alertId = ++fraudAlertCount;
        
        fraudAlerts[alertId] = FraudAlert({
            id: alertId,
            user: user,
            fraudType: fraudType,
            severity: severity,
            description: description,
            timestamp: block.timestamp,
            investigated: false,
            resolved: false,
            resolution: "",
            investigator: address(0)
        });
        
        // Add to suspicious users list if not already there
        if (!_isInSuspiciousList(user)) {
            suspiciousUsers.push(user);
        }
        
        emit FraudAlertCreated(alertId, user, fraudType);
        
        // Report to monitoring system
        if (address(monitoringSystem) != address(0)) {
            monitoringSystem.recordSecurityEvent("fraud_alert", uint256(uint160(user)), msg.sender);
        }
    }

    /**
     * @dev Generate personalized insights for user
     */
    function generatePersonalizedInsights(address user) external onlyAIOperator returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        require(behavior.totalActions > 0, "No behavior data");
        
        uint256 insightCount = 0;
        
        // Game performance insights
        if (behavior.winRate < 30) {
            userInsights[user].push(PersonalizedInsight({
                user: user,
                category: "Performance",
                insight: "Your win rate is below average. Consider studying game strategies.",
                confidence: 85,
                recommendation: "Practice in low-stakes games to improve skills",
                timestamp: block.timestamp,
                actionTaken: false
            }));
            insightCount++;
        }
        
        // Activity pattern insights
        if (_getMostActiveHour(user) >= 22 || _getMostActiveHour(user) <= 4) {
            userInsights[user].push(PersonalizedInsight({
                user: user,
                category: "Health",
                insight: "You're most active during late night hours. Consider playing during day time for better decision making.",
                confidence: 70,
                recommendation: "Set gaming schedule limits and breaks",
                timestamp: block.timestamp,
                actionTaken: false
            }));
            insightCount++;
        }
        
        // Spending pattern insights
        uint256 avgSpending = behavior.totalActions > 0 ? userBehaviors[user].totalActions / 30 : 0; // Simplified
        if (avgSpending > 100) {
            userInsights[user].push(PersonalizedInsight({
                user: user,
                category: "Financial",
                insight: "Your spending has increased significantly. Consider setting daily limits.",
                confidence: 90,
                recommendation: "Enable spending alerts and daily limits",
                timestamp: block.timestamp,
                actionTaken: false
            }));
            insightCount++;
        }
        
        emit InsightGenerated(user, "Multi-category", "Personalized insights generated");
        return insightCount;
    }

    /**
     * @dev Get user's most active hour
     */
    function _getMostActiveHour(address user) internal view returns (uint256) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        uint256 maxActivity = 0;
        uint256 mostActiveHour = 0;
        
        for (uint256 i = 0; i < 24; i++) {
            if (behavior.hourlyActivity[i] > maxActivity) {
                maxActivity = behavior.hourlyActivity[i];
                mostActiveHour = i;
            }
        }
        
        return mostActiveHour;
    }

    /**
     * @dev Check if user is in suspicious list
     */
    function _isInSuspiciousList(address user) internal view returns (bool) {
        for (uint256 i = 0; i < suspiciousUsers.length; i++) {
            if (suspiciousUsers[i] == user) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Investigate fraud alert
     */
    function investigateFraudAlert(
        uint256 alertId,
        string memory resolution,
        bool resolved
    ) external onlyFraudInvestigator {
        require(alertId <= fraudAlertCount, "Alert does not exist");
        
        FraudAlert storage alert = fraudAlerts[alertId];
        alert.investigated = true;
        alert.resolved = resolved;
        alert.resolution = resolution;
        alert.investigator = msg.sender;
        
        if (resolved) {
            // Remove from suspicious list if resolved
            _removeFromSuspiciousList(alert.user);
        }
    }

    /**
     * @dev Remove user from suspicious list
     */
    function _removeFromSuspiciousList(address user) internal {
        for (uint256 i = 0; i < suspiciousUsers.length; i++) {
            if (suspiciousUsers[i] == user) {
                suspiciousUsers[i] = suspiciousUsers[suspiciousUsers.length - 1];
                suspiciousUsers.pop();
                break;
            }
        }
    }

    /**
     * @dev Update ML model parameters
     */
    function updateMLModel(
        string memory modelName,
        uint256[] memory weights,
        uint256 bias,
        uint256 threshold,
        uint256 accuracy
    ) external onlyRole(ANALYTICS_ADMIN_ROLE) {
        MLModel storage model = mlModels[modelName];
        model.weights = weights;
        model.bias = bias;
        model.threshold = threshold;
        model.accuracy = accuracy;
        model.lastTraining = block.timestamp;
        
        emit ModelUpdated(modelName, accuracy);
    }

    /**
     * @dev Whitelist user (removes from analysis)
     */
    function whitelistUser(address user) external onlyFraudInvestigator {
        isWhitelisted[user] = true;
        _removeFromSuspiciousList(user);
    }

    /**
     * @dev Blacklist user
     */
    function blacklistUser(address user) external onlyFraudInvestigator {
        isBlacklisted[user] = true;
    }

    // View functions
    function getUserBehaviorSummary(address user) external view returns (
        uint256 totalActions,
        uint256 riskScore,
        RiskLevel riskLevel,
        bool isBot,
        uint256 winRate
    ) {
        UserBehaviorPattern storage behavior = userBehaviors[user];
        return (
            behavior.totalActions,
            behavior.riskScore,
            behavior.riskLevel,
            behavior.isBot,
            behavior.winRate
        );
    }

    function getUserInsights(address user) external view returns (PersonalizedInsight[] memory) {
        return userInsights[user];
    }

    function getFraudAlert(uint256 alertId) external view returns (FraudAlert memory) {
        return fraudAlerts[alertId];
    }

    function getSuspiciousUsers() external view returns (address[] memory) {
        return suspiciousUsers;
    }

    function getMLModel(string memory modelName) external view returns (MLModel memory) {
        return mlModels[modelName];
    }
}