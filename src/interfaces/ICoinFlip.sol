// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICoinFlip
 * @notice Interface for the CoinFlip game contract
 */
interface ICoinFlip {
    enum Side { Heads, Tails }

    struct Bet {
        address player;
        uint96 amount;
        Side side;
        bool settled;
        uint256 blockNumber;
        uint256 requestId;
    }

    /**
     * @notice Place a coin flip bet
     * @param side The side to bet on (Heads or Tails)
     * @param amount Amount of tokens to bet
     */
    function placeBet(Side side, uint256 amount) external;

    /**
     * @notice Cancel an unfulfilled bet (timeout protection)
     * @param betId ID of the bet to cancel
     */
    function cancelUnfulfilled(uint256 betId) external;

    /**
     * @notice Get bet information
     * @param betId ID of the bet
     * @return Bet information
     */
    function getBet(uint256 betId) external view returns (Bet memory);

    /**
     * @notice Get the minimum bet amount
     * @return Minimum bet amount
     */
    function getMinBet() external view returns (uint256);

    /**
     * @notice Get the maximum bet amount
     * @return Maximum bet amount
     */
    function getMaxBet() external view returns (uint256);

    /**
     * @notice Get total open exposure
     * @return Total open exposure amount
     */
    function getTotalOpenExposure() external view returns (uint256);
}