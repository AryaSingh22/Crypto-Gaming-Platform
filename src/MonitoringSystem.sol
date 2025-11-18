// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GameToken.sol";
import "./GamePass.sol";

/**
 * @title MonitoringSystem
 * @notice Comprehensive monitoring and alerting system for the GameFi platform
 * @dev Tracks metrics, detects anomalies, and provides security monitoring
 */
contract MonitoringSystem is AccessControl, Pausable, ReentrancyGuard {
    /// @notice Role for monitoring operators
    bytes32 public constant MONITOR_ROLE = keccak256("MONITOR_ROLE");
    
    /// @notice Role for security operators
    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");
    
    /// @notice Role for pausing the system
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Monitoring metric types
    enum MetricType {
        TransactionVolume,     // Trading volume in games
        UserActivity,          // Daily/weekly active users
        LiquidityHealth,       // Pool liquidity status
        SecurityIncident,      // Security alerts
        PerformanceMetric,     // Gas usage, response times
        RevenueMetric,         // Fee collection, rewards distribution
        RiskMetric            // Risk assessment scores
    }

    /// @notice Alert severity levels
    enum AlertSeverity {
        Info,       // Informational
        Warning,    // Potential issue
        Critical,   // Requires immediate attention
        Emergency   // System at risk
    }

    /// @notice Monitoring metric structure
    struct Metric {
        MetricType metricType;
        uint256 value;
        uint256 timestamp;
        address source;
        string description;
    }

    /// @notice Security alert structure
    struct SecurityAlert {
        AlertSeverity severity;
        string alertType;
        address target;
        uint256 timestamp;
        string description;
        bool resolved;
        address resolver;
    }

    /// @notice Risk assessment structure
    struct RiskAssessment {
        address target;
        uint256 riskScore;      // 0-100 scale
        uint256 lastAssessment;
        string[] riskFactors;
        bool quarantined;
    }

    /// @notice Platform health metrics
    struct HealthMetrics {
        uint256 totalUsers;
        uint256 activeUsers24h;
        uint256 totalVolumeUSD;
        uint256 volume24hUSD;
        uint256 totalLiquidity;
        uint256 avgGasUsed;
        uint256 lastUpdated;
    }

    /// @notice Circuit breaker thresholds
    struct CircuitBreaker {
        uint256 maxVolumePerHour;
        uint256 maxTransactionsPerBlock;
        uint256 maxGasPerTransaction;
        uint256 minLiquidityRatio;
        bool enabled;
    }

    /// @notice Metrics storage
    mapping(MetricType => Metric[]) public metrics;
    
    /// @notice Security alerts storage
    SecurityAlert[] public securityAlerts;
    
    /// @notice Risk assessments by address
    mapping(address => RiskAssessment) public riskAssessments;
    
    /// @notice Blacklisted addresses
    mapping(address => bool) public blacklisted;
    
    /// @notice Whitelisted addresses (bypass some restrictions)
    mapping(address => bool) public whitelisted;
    
    /// @notice Circuit breaker configuration
    CircuitBreaker public circuitBreaker;
    
    /// @notice Current platform health
    HealthMetrics public healthMetrics;
    
    /// @notice Monitoring configuration
    mapping(MetricType => bool) public metricEnabled;
    mapping(MetricType => uint256) public alertThresholds;
    
    /// @notice Volume tracking for circuit breaker
    mapping(uint256 => uint256) public hourlyVolume; // hour => volume
    mapping(uint256 => uint256) public blockTransactionCount; // block => count
    
    /// @notice Events
    event MetricRecorded(
        MetricType indexed metricType,
        uint256 value,
        address indexed source,
        string description
    );
    
    event SecurityAlertRaised(
        uint256 indexed alertId,
        AlertSeverity indexed severity,
        string alertType,
        address indexed target
    );
    
    event SecurityAlertResolved(
        uint256 indexed alertId,
        address indexed resolver
    );
    
    event RiskAssessmentUpdated(
        address indexed target,
        uint256 oldScore,
        uint256 newScore
    );
    
    event AddressBlacklisted(address indexed target, string reason);
    event AddressWhitelisted(address indexed target, string reason);
    
    event CircuitBreakerTriggered(string reason, uint256 value, uint256 threshold);
    event EmergencyStop(string reason);

    /// @notice Custom errors
    error UnauthorizedSource();
    error InvalidMetricType();
    error InvalidAlertSeverity();
    error AddressAlreadyBlacklisted();
    error CircuitBreakerAlreadyTriggered();
    error InvalidRiskScore();
    error AlertNotFound();
    error AlertAlreadyResolved();

    /**
     * @notice Constructor
     * @param admin Admin address
     */
    constructor(address admin) {
        if (admin == address(0)) revert("Invalid admin address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MONITOR_ROLE, admin);
        _grantRole(SECURITY_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        
        // Initialize default configurations
        _initializeDefaultSettings();
    }

    /**
     * @notice Record a monitoring metric
     * @param metricType Type of metric
     * @param value Metric value
     * @param description Human-readable description
     */
    function recordMetric(
        MetricType metricType,
        uint256 value,
        string calldata description
    ) external onlyRole(MONITOR_ROLE) whenNotPaused {
        if (!metricEnabled[metricType]) return;
        
        // Check for circuit breaker conditions
        _checkCircuitBreaker(metricType, value);
        
        Metric memory metric = Metric({
            metricType: metricType,
            value: value,
            timestamp: block.timestamp,
            source: msg.sender,
            description: description
        });
        
        metrics[metricType].push(metric);
        
        // Check for alert thresholds
        _checkAlertThresholds(metricType, value);
        
        emit MetricRecorded(metricType, value, msg.sender, description);
    }

    /**
     * @notice Raise a security alert
     * @param severity Alert severity
     * @param alertType Type of alert
     * @param target Target address (if applicable)
     * @param description Alert description
     */
    function raiseSecurityAlert(
        AlertSeverity severity,
        string calldata alertType,
        address target,
        string calldata description
    ) external onlyRole(SECURITY_ROLE) whenNotPaused {
        SecurityAlert memory alert = SecurityAlert({
            severity: severity,
            alertType: alertType,
            target: target,
            timestamp: block.timestamp,
            description: description,
            resolved: false,
            resolver: address(0)
        });
        
        securityAlerts.push(alert);
        uint256 alertId = securityAlerts.length - 1;
        
        // Auto-actions based on severity
        if (severity == AlertSeverity.Emergency) {
            _triggerEmergencyStop(description);
        } else if (severity == AlertSeverity.Critical && target != address(0)) {
            _quarantineAddress(target, "Critical security alert");
        }
        
        emit SecurityAlertRaised(alertId, severity, alertType, target);
    }

    /**
     * @notice Resolve a security alert
     * @param alertId Alert ID to resolve
     */
    function resolveSecurityAlert(uint256 alertId) external onlyRole(SECURITY_ROLE) {
        if (alertId >= securityAlerts.length) revert AlertNotFound();
        if (securityAlerts[alertId].resolved) revert AlertAlreadyResolved();
        
        securityAlerts[alertId].resolved = true;
        securityAlerts[alertId].resolver = msg.sender;
        
        emit SecurityAlertResolved(alertId, msg.sender);
    }

    /**
     * @notice Update risk assessment for an address
     * @param target Target address
     * @param riskScore Risk score (0-100)
     * @param riskFactors Array of risk factors
     */
    function updateRiskAssessment(
        address target,
        uint256 riskScore,
        string[] calldata riskFactors
    ) external onlyRole(SECURITY_ROLE) {
        if (riskScore > 100) revert InvalidRiskScore();
        
        uint256 oldScore = riskAssessments[target].riskScore;
        
        riskAssessments[target] = RiskAssessment({
            target: target,
            riskScore: riskScore,
            lastAssessment: block.timestamp,
            riskFactors: riskFactors,
            quarantined: riskScore >= 80 // Auto-quarantine high-risk addresses
        });
        
        emit RiskAssessmentUpdated(target, oldScore, riskScore);
    }

    /**
     * @notice Blacklist an address
     * @param target Address to blacklist
     * @param reason Reason for blacklisting
     */
    function blacklistAddress(
        address target,
        string calldata reason
    ) external onlyRole(SECURITY_ROLE) {
        blacklisted[target] = true;
        emit AddressBlacklisted(target, reason);
    }

    /**
     * @notice Whitelist an address
     * @param target Address to whitelist
     * @param reason Reason for whitelisting
     */
    function whitelistAddress(
        address target,
        string calldata reason
    ) external onlyRole(SECURITY_ROLE) {
        whitelisted[target] = true;
        emit AddressWhitelisted(target, reason);
    }

    /**
     * @notice Remove address from blacklist
     * @param target Address to remove from blacklist
     */
    function removeFromBlacklist(address target) external onlyRole(SECURITY_ROLE) {
        blacklisted[target] = false;
    }

    /**
     * @notice Remove address from whitelist
     * @param target Address to remove from whitelist
     */
    function removeFromWhitelist(address target) external onlyRole(SECURITY_ROLE) {
        whitelisted[target] = false;
    }

    /**
     * @notice Update platform health metrics
     * @param newMetrics Updated health metrics
     */
    function updateHealthMetrics(
        HealthMetrics calldata newMetrics
    ) external onlyRole(MONITOR_ROLE) {
        healthMetrics = newMetrics;
        healthMetrics.lastUpdated = block.timestamp;
    }

    /**
     * @notice Configure circuit breaker
     * @param newConfig New circuit breaker configuration
     */
    function configureCircuitBreaker(
        CircuitBreaker calldata newConfig
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        circuitBreaker = newConfig;
    }

    /**
     * @notice Enable/disable metric monitoring
     * @param metricType Metric type to configure
     * @param enabled Whether to enable monitoring
     */
    function setMetricEnabled(
        MetricType metricType,
        bool enabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        metricEnabled[metricType] = enabled;
    }

    /**
     * @notice Set alert threshold for metric type
     * @param metricType Metric type
     * @param threshold Alert threshold value
     */
    function setAlertThreshold(
        MetricType metricType,
        uint256 threshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        alertThresholds[metricType] = threshold;
    }

    /**
     * @notice Check if address is safe to interact with
     * @param target Address to check
     * @return safe Whether the address is safe
     */
    function isAddressSafe(address target) external view returns (bool safe) {
        if (blacklisted[target]) return false;
        if (whitelisted[target]) return true;
        
        RiskAssessment memory assessment = riskAssessments[target];
        if (assessment.quarantined) return false;
        if (assessment.riskScore >= 70) return false;
        
        return true;
    }

    /**
     * @notice Get recent metrics for a type
     * @param metricType Type of metric
     * @param count Number of recent metrics to return
     * @return Recent metrics array
     */
    function getRecentMetrics(
        MetricType metricType,
        uint256 count
    ) external view returns (Metric[] memory) {
        Metric[] storage metricArray = metrics[metricType];
        uint256 arrayLength = metricArray.length;
        
        if (count > arrayLength) count = arrayLength;
        if (count == 0) return new Metric[](0);
        
        Metric[] memory recentMetrics = new Metric[](count);
        uint256 startIndex = arrayLength - count;
        
        for (uint256 i = 0; i < count; i++) {
            recentMetrics[i] = metricArray[startIndex + i];
        }
        
        return recentMetrics;
    }

    /**
     * @notice Get unresolved security alerts
     * @return Unresolved alerts array
     */
    function getUnresolvedAlerts() external view returns (SecurityAlert[] memory) {
        uint256 unresolvedCount = 0;
        
        // Count unresolved alerts
        for (uint256 i = 0; i < securityAlerts.length; i++) {
            if (!securityAlerts[i].resolved) {
                unresolvedCount++;
            }
        }
        
        // Build array of unresolved alerts
        SecurityAlert[] memory unresolvedAlerts = new SecurityAlert[](unresolvedCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < securityAlerts.length; i++) {
            if (!securityAlerts[i].resolved) {
                unresolvedAlerts[index] = securityAlerts[i];
                index++;
            }
        }
        
        return unresolvedAlerts;
    }

    /**
     * @notice Emergency pause all monitored systems
     */
    function emergencyPause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit EmergencyStop("Manual emergency pause triggered");
    }

    /**
     * @notice Resume operations after pause
     */
    function resume() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Check circuit breaker conditions
     * @param metricType Type of metric being recorded
     * @param value Metric value
     */
    function _checkCircuitBreaker(MetricType metricType, uint256 value) internal {
        if (!circuitBreaker.enabled) return;
        
        if (metricType == MetricType.TransactionVolume) {
            uint256 currentHour = block.timestamp / 3600;
            hourlyVolume[currentHour] += value;
            
            if (hourlyVolume[currentHour] > circuitBreaker.maxVolumePerHour) {
                emit CircuitBreakerTriggered(
                    "Hourly volume exceeded",
                    hourlyVolume[currentHour],
                    circuitBreaker.maxVolumePerHour
                );
                _triggerEmergencyStop("Circuit breaker: Excessive volume");
            }
        }
        
        if (metricType == MetricType.PerformanceMetric) {
            blockTransactionCount[block.number]++;
            
            if (blockTransactionCount[block.number] > circuitBreaker.maxTransactionsPerBlock) {
                emit CircuitBreakerTriggered(
                    "Block transaction limit exceeded",
                    blockTransactionCount[block.number],
                    circuitBreaker.maxTransactionsPerBlock
                );
                _triggerEmergencyStop("Circuit breaker: Too many transactions");
            }
        }
    }

    /**
     * @notice Check if metric exceeds alert thresholds
     * @param metricType Type of metric
     * @param value Metric value
     */
    function _checkAlertThresholds(MetricType metricType, uint256 value) internal {
        uint256 threshold = alertThresholds[metricType];
        if (threshold > 0 && value > threshold) {
            // Auto-raise alert for threshold breach
            securityAlerts.push(SecurityAlert({
                severity: AlertSeverity.Warning,
                alertType: "Threshold Exceeded",
                target: address(0),
                timestamp: block.timestamp,
                description: string(abi.encodePacked(
                    "Metric threshold exceeded: ",
                    _metricTypeToString(metricType)
                )),
                resolved: false,
                resolver: address(0)
            }));
        }
    }

    /**
     * @notice Quarantine an address
     * @param target Address to quarantine
     * @param reason Reason for quarantine
     */
    function _quarantineAddress(address target, string memory reason) internal {
        riskAssessments[target].quarantined = true;
        riskAssessments[target].riskScore = 100;
        emit AddressBlacklisted(target, reason);
    }

    /**
     * @notice Trigger emergency stop
     * @param reason Reason for emergency stop
     */
    function _triggerEmergencyStop(string memory reason) internal {
        _pause();
        emit EmergencyStop(reason);
    }

    /**
     * @notice Convert metric type to string
     * @param metricType Metric type enum
     * @return String representation
     */
    function _metricTypeToString(MetricType metricType) internal pure returns (string memory) {
        if (metricType == MetricType.TransactionVolume) return "TransactionVolume";
        if (metricType == MetricType.UserActivity) return "UserActivity";
        if (metricType == MetricType.LiquidityHealth) return "LiquidityHealth";
        if (metricType == MetricType.SecurityIncident) return "SecurityIncident";
        if (metricType == MetricType.PerformanceMetric) return "PerformanceMetric";
        if (metricType == MetricType.RevenueMetric) return "RevenueMetric";
        if (metricType == MetricType.RiskMetric) return "RiskMetric";
        return "Unknown";
    }

    /**
     * @notice Initialize default monitoring settings
     */
    function _initializeDefaultSettings() internal {
        // Enable all metric types by default
        metricEnabled[MetricType.TransactionVolume] = true;
        metricEnabled[MetricType.UserActivity] = true;
        metricEnabled[MetricType.LiquidityHealth] = true;
        metricEnabled[MetricType.SecurityIncident] = true;
        metricEnabled[MetricType.PerformanceMetric] = true;
        metricEnabled[MetricType.RevenueMetric] = true;
        metricEnabled[MetricType.RiskMetric] = true;
        
        // Set default alert thresholds
        alertThresholds[MetricType.TransactionVolume] = 1_000_000e18; // 1M tokens
        alertThresholds[MetricType.UserActivity] = 10000; // 10k users
        alertThresholds[MetricType.LiquidityHealth] = 50; // 50% liquidity ratio
        alertThresholds[MetricType.PerformanceMetric] = 500000; // 500k gas
        
        // Set default circuit breaker
        circuitBreaker = CircuitBreaker({
            maxVolumePerHour: 10_000_000e18, // 10M tokens per hour
            maxTransactionsPerBlock: 100,     // 100 transactions per block
            maxGasPerTransaction: 1_000_000,  // 1M gas per transaction
            minLiquidityRatio: 20,            // 20% minimum liquidity
            enabled: true
        });
    }
}