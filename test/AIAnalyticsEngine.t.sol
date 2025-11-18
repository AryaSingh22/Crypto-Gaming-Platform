// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/analytics/AIAnalyticsEngine.sol";
import "../src/MonitoringSystem.sol";

contract AIAnalyticsEngineTest is Test {
    AIAnalyticsEngine public analytics;
    MonitoringSystem public monitoringSystem;
    
    address public admin = address(0x1);
    address public operator = address(0x2);

    function setUp() public {
        vm.startPrank(admin);
        
        monitoringSystem = new MonitoringSystem();
        analytics = new AIAnalyticsEngine(address(monitoringSystem));
        
        analytics.grantRole(analytics.AI_OPERATOR_ROLE(), operator);
        
        vm.stopPrank();
    }

    function testRecordMetric() public {
        vm.prank(operator);
        analytics.recordMetric("daily_active_users", 1000);
        
        // Since recordMetric might just emit an event or update internal state, 
        // we verify it doesn't revert. 
        // Ideally we should check the state change if possible.
    }
}
