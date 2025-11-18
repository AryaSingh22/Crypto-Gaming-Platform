// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MonitoringSystem.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";

contract MonitoringSystemTest is Test {
    MonitoringSystem public monitoringSystem;
    GameToken public gameToken;
    GamePass public gamePass;
    
    address public admin = address(0x1);
    address public monitor = address(0x2);
    address public security = address(0x3);
    address public user1 = address(0x4);
    address public user2 = address(0x5);
    
    event MetricRecorded(
        MonitoringSystem.MetricType indexed metricType,
        uint256 value,
        address indexed source,
        string description
    );
    
    event SecurityAlertRaised(
        uint256 indexed alertId,
        MonitoringSystem.AlertSeverity indexed severity,
        string alertType,
        address indexed target
    );
    
    event SecurityAlertResolved(
        uint256 indexed alertId,
        address indexed resolver
    );
    
    event CircuitBreakerTriggered(string reason, uint256 value, uint256 threshold);
    event EmergencyStop(string reason);

    function setUp() public {
        // Deploy monitoring system
        monitoringSystem = new MonitoringSystem(admin);
        
        // Deploy dependencies for context
        gameToken = new GameToken(
            "Game Token",
            "GAME",
            1_000_000e18,
            0,
            address(0x100), // treasury
            admin
        );
        
        gamePass = new GamePass(
            "Game Pass",
            "GPASS",
            "https://api.example.com/metadata/",
            address(0x100), // treasury
            admin
        );
        
        // Setup roles
        vm.startPrank(admin);
        monitoringSystem.grantRole(monitoringSystem.MONITOR_ROLE(), monitor);
        monitoringSystem.grantRole(monitoringSystem.SECURITY_ROLE(), security);
        vm.stopPrank();
    }

    function testInitialConfiguration() public view{
        // Check roles
        assertTrue(monitoringSystem.hasRole(monitoringSystem.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(monitoringSystem.hasRole(monitoringSystem.MONITOR_ROLE(), admin));
        assertTrue(monitoringSystem.hasRole(monitoringSystem.MONITOR_ROLE(), monitor));
        assertTrue(monitoringSystem.hasRole(monitoringSystem.SECURITY_ROLE(), security));
        
        // Check default settings
        assertTrue(monitoringSystem.metricEnabled(MonitoringSystem.MetricType.TransactionVolume));
        assertTrue(monitoringSystem.metricEnabled(MonitoringSystem.MetricType.UserActivity));
        assertTrue(monitoringSystem.metricEnabled(MonitoringSystem.MetricType.SecurityIncident));
        
        // Check circuit breaker
        (, , , , bool enabled) = monitoringSystem.circuitBreaker();
        assertTrue(enabled);
        
        // Check health metrics initialization
        (uint256 totalUsers, , , , , , uint256 lastUpdated) = monitoringSystem.healthMetrics();
        assertEq(totalUsers, 0);
        assertEq(lastUpdated, 0);
    }

    function testRecordMetric() public {
        uint256 value = 1000e18;
        string memory description = "Test transaction volume";
        
        vm.expectEmit(true, true, false, true);
        emit MetricRecorded(
            MonitoringSystem.MetricType.TransactionVolume,
            value,
            monitor,
            description
        );
        
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.TransactionVolume,
            value,
            description
        );
        
        // Verify metric was recorded
        MonitoringSystem.Metric[] memory metrics = monitoringSystem.getRecentMetrics(
            MonitoringSystem.MetricType.TransactionVolume,
            1
        );
        
        assertEq(metrics.length, 1);
        assertEq(metrics[0].value, value);
        assertEq(metrics[0].source, monitor);
    }

    function testRecordMetricUnauthorized() public {
        vm.expectRevert();
        vm.prank(user1);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.TransactionVolume,
            1000e18,
            "Unauthorized test"
        );
    }

    function testRecordMetricDisabled() public {
        // Disable metric type
        vm.prank(admin);
        monitoringSystem.setMetricEnabled(MonitoringSystem.MetricType.TransactionVolume, false);
        
        // Recording should not emit event or store metric
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.TransactionVolume,
            1000e18,
            "Disabled metric test"
        );
        
        // Verify no metrics recorded
        MonitoringSystem.Metric[] memory metrics = monitoringSystem.getRecentMetrics(
            MonitoringSystem.MetricType.TransactionVolume,
            10
        );
        assertEq(metrics.length, 0);
    }

    function testSecurityAlert() public {
        vm.expectEmit(true, true, false, false);
        emit SecurityAlertRaised(
            0,
            MonitoringSystem.AlertSeverity.Warning,
            "Suspicious Activity",
            user1
        );
        
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Warning,
            "Suspicious Activity",
            user1,
            "User showing unusual transaction patterns"
        );
        
        // Verify alert was recorded
        (
            MonitoringSystem.AlertSeverity severity,
            string memory alertType,
            address target,
            ,  // timestamp - not used
            ,  // description - not used
            bool resolved,
            address resolver
        ) = monitoringSystem.securityAlerts(0);
        
        assertEq(uint8(severity), uint8(MonitoringSystem.AlertSeverity.Warning));
        assertEq(alertType, "Suspicious Activity");
        assertEq(target, user1);
        assertFalse(resolved);
        assertEq(resolver, address(0));
    }

    function testCriticalAlertQuarantine() public {
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Critical,
            "Malicious Activity",
            user1,
            "User attempting exploit"
        );
        
        // Verify user was quarantined
        // Fixed: Access fields individually, excluding riskFactors as dynamic arrays aren't returned by struct getters
        (
            address target,
            uint256 riskScore,
            uint256 lastAssessment,
            bool quarantined
        ) = monitoringSystem.riskAssessments(user1);
        
        assertEq(target, user1);
        assertEq(riskScore, 100);
        assertTrue(quarantined);
        assertEq(lastAssessment, block.timestamp);
    }

    function testEmergencyAlert() public {
        vm.expectEmit(false, false, false, true);
        emit EmergencyStop("Critical security breach detected");
        
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Emergency,
            "Security Breach",
            address(0),
            "Critical security breach detected"
        );
        
        // Verify system was paused
        assertTrue(monitoringSystem.paused());
    }

    function testResolveSecurityAlert() public {
        // Raise alert first
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Warning,
            "Test Alert",
            user1,
            "Test description"
        );
        
        vm.expectEmit(true, true, false, false);
        emit SecurityAlertResolved(0, security);
        
        vm.prank(security);
        monitoringSystem.resolveSecurityAlert(0);
        
        // Verify alert was resolved
        (, , , , , bool resolved, address resolver) = monitoringSystem.securityAlerts(0);
        assertTrue(resolved);
        assertEq(resolver, security);
    }

    function testResolveNonexistentAlert() public {
        vm.expectRevert(MonitoringSystem.AlertNotFound.selector);
        vm.prank(security);
        monitoringSystem.resolveSecurityAlert(0);
    }

    function testResolveAlreadyResolvedAlert() public {
        // Raise and resolve alert
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Info,
            "Test",
            address(0),
            "Test"
        );
        
        vm.prank(security);
        monitoringSystem.resolveSecurityAlert(0);
        
        // Try to resolve again
        vm.expectRevert(MonitoringSystem.AlertAlreadyResolved.selector);
        vm.prank(security);
        monitoringSystem.resolveSecurityAlert(0);
    }

    function testRiskAssessment() public {
        string[] memory riskFactors = new string[](2);
        riskFactors[0] = "High transaction frequency";
        riskFactors[1] = "Unusual gas patterns";
        
        vm.prank(security);
        monitoringSystem.updateRiskAssessment(user1, 75, riskFactors);
        
        // Fixed: Access fields individually, excluding riskFactors as dynamic arrays aren't returned by struct getters
        (
            address target,
            uint256 riskScore,
            uint256 lastAssessment,
            bool quarantined
        ) = monitoringSystem.riskAssessments(user1);
        
        assertEq(target, user1);
        assertEq(riskScore, 75);
        assertEq(lastAssessment, block.timestamp);
        assertFalse(quarantined); // Should not be quarantined under 80
    }

    function testHighRiskAutoQuarantine() public {
        string[] memory riskFactors = new string[](1);
        riskFactors[0] = "Confirmed malicious activity";
        
        vm.prank(security);
        monitoringSystem.updateRiskAssessment(user1, 85, riskFactors);
        
        // Fixed: Access fields individually, excluding riskFactors as dynamic arrays aren't returned by struct getters
        (
            , // address target - not used, so we skip it
            uint256 riskScore,
            , // lastAssessment - not used, so we skip it
            bool quarantined
        ) = monitoringSystem.riskAssessments(user1);
        
        assertEq(riskScore, 85); // Verify the risk score was set correctly
        assertTrue(quarantined); // Should be auto-quarantined at 85
    }

    function testInvalidRiskScore() public {
        string[] memory riskFactors = new string[](0);
        
        vm.expectRevert(MonitoringSystem.InvalidRiskScore.selector);
        vm.prank(security);
        monitoringSystem.updateRiskAssessment(user1, 101, riskFactors);
    }

    function testBlacklistAddress() public {
        vm.prank(security);
        monitoringSystem.blacklistAddress(user1, "Confirmed malicious activity");
        
        assertTrue(monitoringSystem.blacklisted(user1));
        assertFalse(monitoringSystem.isAddressSafe(user1));
    }

    function testWhitelistAddress() public {
        vm.prank(security);
        monitoringSystem.whitelistAddress(user1, "Verified trusted user");
        
        assertTrue(monitoringSystem.whitelisted(user1));
        assertTrue(monitoringSystem.isAddressSafe(user1));
    }

    function testIsAddressSafe() public {
        // Normal address should be safe
        assertTrue(monitoringSystem.isAddressSafe(user1));
        
        // Blacklisted address should not be safe
        vm.prank(security);
        monitoringSystem.blacklistAddress(user1, "Test");
        assertFalse(monitoringSystem.isAddressSafe(user1));
        
        // Whitelisted address should be safe even if blacklisted
        vm.prank(security);
        monitoringSystem.whitelistAddress(user1, "Test");
        assertTrue(monitoringSystem.isAddressSafe(user1));
        
        // High risk address should not be safe
        vm.prank(security);
        monitoringSystem.removeFromWhitelist(user1);
        vm.prank(security);
        monitoringSystem.removeFromBlacklist(user1);
        
        string[] memory riskFactors = new string[](1);
        riskFactors[0] = "High risk behavior";
        vm.prank(security);
        monitoringSystem.updateRiskAssessment(user1, 75, riskFactors);
        assertFalse(monitoringSystem.isAddressSafe(user1));
    }

    function testCircuitBreakerVolumeThreshold() public {
        // Set low threshold for testing
        MonitoringSystem.CircuitBreaker memory newConfig = MonitoringSystem.CircuitBreaker({
            maxVolumePerHour: 100e18,
            maxTransactionsPerBlock: 100,
            maxGasPerTransaction: 1_000_000,
            minLiquidityRatio: 20,
            enabled: true
        });
        
        vm.prank(admin);
        monitoringSystem.configureCircuitBreaker(newConfig);
        
        // This should trigger circuit breaker
        vm.expectEmit(false, false, false, true);
        emit CircuitBreakerTriggered("Hourly volume exceeded", 150e18, 100e18);
        
        vm.expectEmit(false, false, false, true);
        emit EmergencyStop("Circuit breaker: Excessive volume");
        
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.TransactionVolume,
            150e18,
            "Large volume test"
        );
        
        assertTrue(monitoringSystem.paused());
    }

    function testCircuitBreakerTransactionThreshold() public {
        // Set low threshold for testing
        MonitoringSystem.CircuitBreaker memory newConfig = MonitoringSystem.CircuitBreaker({
            maxVolumePerHour: 10_000_000e18,
            maxTransactionsPerBlock: 2,
            maxGasPerTransaction: 1_000_000,
            minLiquidityRatio: 20,
            enabled: true
        });
        
        vm.prank(admin);
        monitoringSystem.configureCircuitBreaker(newConfig);
        
        // Record transactions in same block to trigger limit
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.PerformanceMetric,
            1,
            "Transaction 1"
        );
        
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.PerformanceMetric,
            1,
            "Transaction 2"
        );
        
        // This should trigger circuit breaker
        vm.expectEmit(false, false, false, true);
        emit CircuitBreakerTriggered("Block transaction limit exceeded", 3, 2);
        
        vm.expectEmit(false, false, false, true);
        emit EmergencyStop("Circuit breaker: Too many transactions");
        
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.PerformanceMetric,
            1,
            "Transaction 3"
        );
        
        assertTrue(monitoringSystem.paused());
    }

    function testAlertThresholds() public {
        // Set low threshold for testing
        vm.prank(admin);
        monitoringSystem.setAlertThreshold(MonitoringSystem.MetricType.TransactionVolume, 50e18);
        
        // This should trigger threshold alert
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.TransactionVolume,
            100e18,
            "Threshold test"
        );
        
        // Check that alert was automatically raised
        (, string memory alertType, , , string memory description, bool resolved,) = 
            monitoringSystem.securityAlerts(0);
        
        assertEq(alertType, "Threshold Exceeded");
        assertFalse(resolved);
        assertTrue(bytes(description).length > 0);
    }

    function testHealthMetricsUpdate() public {
        MonitoringSystem.HealthMetrics memory newMetrics = MonitoringSystem.HealthMetrics({
            totalUsers: 1000,
            activeUsers24h: 500,
            totalVolumeUSD: 1_000_000,
            volume24hUSD: 50_000,
            totalLiquidity: 2_000_000,
            avgGasUsed: 200_000,
            lastUpdated: 0 // Will be set automatically
        });
        
        vm.prank(monitor);
        monitoringSystem.updateHealthMetrics(newMetrics);
        
        (
            uint256 totalUsers,
            uint256 activeUsers24h,
            uint256 totalVolumeUSD,
            uint256 volume24hUSD,
            uint256 totalLiquidity,
            uint256 avgGasUsed,
            uint256 lastUpdated
        ) = monitoringSystem.healthMetrics();
        
        assertEq(totalUsers, 1000);
        assertEq(activeUsers24h, 500);
        assertEq(totalVolumeUSD, 1_000_000);
        assertEq(volume24hUSD, 50_000);
        assertEq(totalLiquidity, 2_000_000);
        assertEq(avgGasUsed, 200_000);
        assertEq(lastUpdated, block.timestamp);
    }

    function testGetRecentMetrics() public {
        // Record multiple metrics
        for (uint256 i = 1; i <= 5; i++) {
            vm.prank(monitor);
            monitoringSystem.recordMetric(
                MonitoringSystem.MetricType.UserActivity,
                i * 100,
                string(abi.encodePacked("Metric ", i))
            );
        }
        
        // Get recent metrics
        MonitoringSystem.Metric[] memory metrics = monitoringSystem.getRecentMetrics(
            MonitoringSystem.MetricType.UserActivity,
            3
        );
        
        assertEq(metrics.length, 3);
        assertEq(metrics[0].value, 300); // Should be most recent 3
        assertEq(metrics[1].value, 400);
        assertEq(metrics[2].value, 500);
    }

    function testGetUnresolvedAlerts() public {
        // Raise multiple alerts
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Warning,
            "Alert 1",
            address(0),
            "Description 1"
        );
        
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Critical,
            "Alert 2",
            user1,
            "Description 2"
        );
        
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Info,
            "Alert 3",
            address(0),
            "Description 3"
        );
        
        // Resolve one alert
        vm.prank(security);
        monitoringSystem.resolveSecurityAlert(1);
        
        // Get unresolved alerts
        MonitoringSystem.SecurityAlert[] memory unresolvedAlerts = 
            monitoringSystem.getUnresolvedAlerts();
        
        assertEq(unresolvedAlerts.length, 2);
        assertEq(unresolvedAlerts[0].alertType, "Alert 1");
        assertEq(unresolvedAlerts[1].alertType, "Alert 3");
    }

    function testPauseUnpause() public {
        // Test pause functionality through emergencyPause
        vm.expectEmit(false, false, false, true);
        emit EmergencyStop("Manual emergency pause triggered");
        
        vm.prank(admin);
        monitoringSystem.emergencyPause();
        assertTrue(monitoringSystem.paused());
        
        // Test resume functionality
        vm.prank(admin);
        monitoringSystem.resume();
        assertFalse(monitoringSystem.paused());
    }
    
    function testAuthorizedPause() public {
        // Only accounts with PAUSER_ROLE should be able to pause
        vm.prank(admin);
        // Fixed: The pause function is internal, so we can't call it directly from tests
        // We'll test the pause functionality through the emergency stop mechanism instead
        vm.expectEmit(false, false, false, true);
        emit EmergencyStop("Test emergency stop");
        
        vm.prank(security); // Security role can trigger emergency stop
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Emergency,
            "Test",
            address(0),
            "Test emergency stop"
        );
        
        assertTrue(monitoringSystem.paused());
    }

    function testEmergencyPause() public {
        vm.expectEmit(false, false, false, true);
        emit EmergencyStop("Manual emergency pause triggered");
        
        vm.prank(admin); // Admin has PAUSER_ROLE by default
        monitoringSystem.emergencyPause();
        
        assertTrue(monitoringSystem.paused());
    }

    function testResumeOperations() public {
        // Pause first
        vm.prank(admin);
        monitoringSystem.emergencyPause();
        assertTrue(monitoringSystem.paused());
        
        // Resume
        vm.prank(admin);
        monitoringSystem.resume();
        assertFalse(monitoringSystem.paused());
    }

    function testAccessControlForAdminFunctions() public {
        // Non-admin cannot configure circuit breaker
        MonitoringSystem.CircuitBreaker memory config;
        vm.expectRevert();
        vm.prank(user1);
        monitoringSystem.configureCircuitBreaker(config);
        
        // Non-admin cannot set metric enabled
        vm.expectRevert();
        vm.prank(user1);
        monitoringSystem.setMetricEnabled(MonitoringSystem.MetricType.TransactionVolume, false);
        
        // Non-admin cannot set alert threshold
        vm.expectRevert();
        vm.prank(user1);
        monitoringSystem.setAlertThreshold(MonitoringSystem.MetricType.TransactionVolume, 1000);
    }

    function testPausedOperations() public {
        // Pause system
        vm.prank(admin);
        monitoringSystem.emergencyPause();
        
        // Recording metrics should fail when paused
        vm.expectRevert("Pausable: paused");
        vm.prank(monitor);
        monitoringSystem.recordMetric(
            MonitoringSystem.MetricType.TransactionVolume,
            1000e18,
            "Should fail"
        );
        
        // Raising alerts should fail when paused
        vm.expectRevert("Pausable: paused");
        vm.prank(security);
        monitoringSystem.raiseSecurityAlert(
            MonitoringSystem.AlertSeverity.Warning,
            "Should fail",
            address(0),
            "Should fail"
        );
    }
}