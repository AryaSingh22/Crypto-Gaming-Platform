// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMonitoringSystem
 * @dev Interface for the MonitoringSystem contract used across Phase 3 contracts
 */
interface IMonitoringSystem {
    /**
     * @dev Record a general event in the monitoring system
     * @param eventType Type of event (e.g., "tournament_created", "fraud_alert")
     * @param eventData Numeric data associated with the event
     * @param user Address of the user involved in the event
     */
    function recordEvent(string calldata eventType, uint256 eventData, address user) external;

    /**
     * @dev Record a security event in the monitoring system
     * @param eventType Type of security event (e.g., "fraud_alert", "suspicious_activity")
     * @param eventData Numeric data associated with the event
     * @param user Address of the user involved in the event
     */
    function recordSecurityEvent(string calldata eventType, uint256 eventData, address user) external;

    /**
     * @dev Record a game-related event
     * @param gameType Type of game (e.g., "tournament", "coin_flip")
     * @param eventData Numeric data associated with the event
     * @param user Address of the user involved in the event
     */
    function recordGameEvent(string calldata gameType, uint256 eventData, address user) external;

    /**
     * @dev Record a financial transaction event
     * @param transactionType Type of transaction (e.g., "stake", "withdraw", "bridge")
     * @param amount Amount involved in the transaction
     * @param user Address of the user involved in the transaction
     */
    function recordTransaction(string calldata transactionType, uint256 amount, address user) external;

    /**
     * @dev Get the current risk score for a user
     * @param user Address of the user
     * @return riskScore The risk score (0-100)
     */
    function getUserRiskScore(address user) external view returns (uint256 riskScore);

    /**
     * @dev Check if a user is flagged as high risk
     * @param user Address of the user
     * @return isHighRisk True if user is flagged as high risk
     */
    function isHighRiskUser(address user) external view returns (bool isHighRisk);

    /**
     * @dev Get monitoring statistics
     * @return totalEvents Total number of events recorded
     * @return totalSecurityEvents Total number of security events
     * @return totalUsers Total number of unique users monitored
     */
    function getMonitoringStats() external view returns (
        uint256 totalEvents,
        uint256 totalSecurityEvents,
        uint256 totalUsers
    );
}