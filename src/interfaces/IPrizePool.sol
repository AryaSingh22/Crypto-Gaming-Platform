// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IPrizePool
 * @notice Interface for the PrizePool contract that manages game liquidity and payouts
 */
interface IPrizePool {
    /**
     * @notice Deposit tokens into the prize pool
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Authorize or deauthorize a game contract to request payouts
     * @param game Address of the game contract
     * @param allowed Whether the game is authorized
     */
    function authorizeGame(address game, bool allowed) external;

    /**
     * @notice Set the house fee in basis points
     * @param bps Fee in basis points (100 = 1%)
     */
    function setFeeBps(uint16 bps) external;

    /**
     * @notice Pay out winnings to a player (called by authorized games only)
     * @param to Address to pay out to
     * @param grossWin Gross winning amount before fees
     */
    function payout(address to, uint256 grossWin) external;

    /**
     * @notice Get the available balance for payouts
     * @return Available balance
     */
    function getAvailableBalance() external view returns (uint256);

    /**
     * @notice Check if a game contract is authorized
     * @param game Address of the game contract
     * @return Whether the game is authorized
     */
    function isGameAuthorized(address game) external view returns (bool);
}