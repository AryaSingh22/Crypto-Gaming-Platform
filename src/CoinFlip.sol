// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./interfaces/ICoinFlip.sol";
import "./interfaces/IPrizePool.sol";
import "./GamePass.sol";

/**
 * @title CoinFlip
 * @notice Provably fair coin flip game using Chainlink VRF
 * @dev Players bet on heads or tails, outcomes determined by VRF randomness
 */
contract CoinFlip is ICoinFlip, VRFConsumerBaseV2, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    /// @notice Role for updating game parameters
    bytes32 public constant GAME_ADMIN_ROLE = keccak256("GAME_ADMIN_ROLE");

    /// @notice VRF Coordinator interface
    VRFCoordinatorV2Interface private immutable vrfCoordinator;

    /// @notice VRF subscription ID
    uint64 private immutable subscriptionId;

    /// @notice VRF key hash (gas lane)
    bytes32 private immutable keyHash;

    /// @notice VRF request confirmations
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @notice VRF callback gas limit
    uint32 private constant CALLBACK_GAS_LIMIT = 200000;

    /// @notice Number of random words to request
    uint32 private constant NUM_WORDS = 1;

    /// @notice Timeout blocks for bet cancellation
    uint256 public constant TIMEOUT_BLOCKS = 200;

    /// @notice Prize pool contract
    IPrizePool public immutable prizePool;

    /// @notice Game token
    IERC20 public immutable gameToken;

    /// @notice Game pass contract for access control
    GamePass public immutable gamePass;

    /// @notice Minimum bet amount
    uint256 public minBet;

    /// @notice Maximum bet amount
    uint256 public maxBet;

    /// @notice Total open exposure (sum of potential payouts)
    uint256 public totalOpenExposure;

    /// @notice Next bet ID
    uint256 public nextBetId;

    /// @notice Mapping from VRF request ID to bet ID
    mapping(uint256 => uint256) private requestIdToBetId;

    /// @notice Mapping from bet ID to bet data
    mapping(uint256 => Bet) public bets;

    /// @notice Player bet history
    mapping(address => uint256[]) public playerBets;

    /// @notice Total bets placed
    uint256 public totalBets;

    /// @notice Total volume (sum of all bet amounts)
    uint256 public totalVolume;

    /// @notice Events
    event BetPlaced(uint256 indexed betId, address indexed player, uint256 amount, Side side, uint256 requestId);
    event BetSettled(uint256 indexed betId, address indexed player, bool won, uint256 payout, uint256 randomWord);
    event BetCancelled(uint256 indexed betId, address indexed player, uint256 refund);
    event MinBetUpdated(uint256 newMinBet);
    event MaxBetUpdated(uint256 newMaxBet);
    event VRFRequestFailed(uint256 indexed requestId, uint256 indexed betId);

    /// @notice Custom errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidBetAmount();
    error InsufficientVaultBalance();
    error ExceedsMaxExposure();
    error NoPassRequired();
    error BetAlreadySettled();
    error BetNotFound();
    error TooEarlyToCancel();
    error NotBetOwner();
    error InvalidSide();

    /// @notice Modifier to check if caller has a pass
    modifier requiresPass() {
        if (!gamePass.hasPass(msg.sender)) revert NoPassRequired();
        _;
    }

    /**
     * @notice Constructor
     * @param vrfCoordinatorAddress Chainlink VRF Coordinator address
     * @param subscriptionId_ VRF subscription ID
     * @param keyHash_ VRF key hash
     * @param prizePoolAddress Prize pool contract address
     * @param gameTokenAddress Game token address
     * @param gamePassAddress Game pass contract address
     * @param minBetAmount Minimum bet amount
     * @param maxBetAmount Maximum bet amount
     * @param admin Admin address
     */
    constructor(
        address vrfCoordinatorAddress,
        uint64 subscriptionId_,
        bytes32 keyHash_,
        address prizePoolAddress,
        address gameTokenAddress,
        address gamePassAddress,
        uint256 minBetAmount,
        uint256 maxBetAmount,
        address admin
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) {
        if (
            vrfCoordinatorAddress == address(0) ||
            prizePoolAddress == address(0) ||
            gameTokenAddress == address(0) ||
            gamePassAddress == address(0) ||
            admin == address(0)
        ) revert ZeroAddress();

        if (minBetAmount == 0 || maxBetAmount == 0 || maxBetAmount < minBetAmount) {
            revert InvalidBetAmount();
        }

        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        subscriptionId = subscriptionId_;
        keyHash = keyHash_;
        prizePool = IPrizePool(prizePoolAddress);
        gameToken = IERC20(gameTokenAddress);
        gamePass = GamePass(gamePassAddress);
        minBet = minBetAmount;
        maxBet = maxBetAmount;

        // Grant roles to admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _grantRole(GAME_ADMIN_ROLE, admin);

        // Start bet IDs at 1
        nextBetId = 1;
    }

    /**
     * @notice Place a coin flip bet
     * @param side The side to bet on (Heads or Tails)
     * @param amount Amount of tokens to bet
     */
    function placeBet(Side side, uint256 amount) external override requiresPass whenNotPaused nonReentrant {
        if (uint8(side) > uint8(Side.Tails)) revert InvalidSide();
        if (amount < minBet || amount > maxBet) revert InvalidBetAmount();

        // Calculate potential payout (2x bet amount)
        uint256 potentialPayout = amount * 2;

        // Check vault can cover the payout and exposure limits
        uint256 vaultBalance = prizePool.getAvailableBalance();
        if (vaultBalance < potentialPayout) revert InsufficientVaultBalance();
        if (totalOpenExposure + potentialPayout > vaultBalance) revert ExceedsMaxExposure();

        // Transfer bet amount from player
        gameToken.safeTransferFrom(msg.sender, address(this), amount);

        // Request randomness from VRF
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        // Store bet data
        uint256 betId = nextBetId++;
        bets[betId] = Bet({
            player: msg.sender,
            amount: uint96(amount),
            side: side,
            settled: false,
            blockNumber: block.number,
            requestId: requestId
        });

        // Map request ID to bet ID
        requestIdToBetId[requestId] = betId;

        // Update exposure and stats
        totalOpenExposure += potentialPayout;
        totalBets++;
        totalVolume += amount;
        playerBets[msg.sender].push(betId);

        emit BetPlaced(betId, msg.sender, amount, side, requestId);
    }

    /**
     * @notice Chainlink VRF callback function
     * @param requestId VRF request ID
     * @param randomWords Array of random words
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 betId = requestIdToBetId[requestId];
        if (betId == 0) return; // Invalid request ID

        Bet storage bet = bets[betId];
        if (bet.settled) return; // Already settled

        // Settle the bet
        _settleBet(betId, randomWords[0]);
    }

    /**
     * @notice Internal function to settle a bet
     * @param betId ID of the bet to settle
     * @param randomWord Random word from VRF
     */
    function _settleBet(uint256 betId, uint256 randomWord) internal {
        Bet storage bet = bets[betId];
        
        // Determine outcome (0 = Heads, 1 = Tails)
        Side outcome = Side(randomWord % 2);
        bool won = (bet.side == outcome);

        // Calculate payout
        uint256 potentialPayout = uint256(bet.amount) * 2;
        uint256 payout = won ? potentialPayout : 0;

        // Update exposure
        totalOpenExposure -= potentialPayout;

        // Mark bet as settled
        bet.settled = true;

        if (won) {
            // Player wins - pay out via prize pool
            prizePool.payout(bet.player, payout);
        }

        // Return remaining bet amount to prize pool (house keeps losing bets)
        uint256 remainingAmount = uint256(bet.amount);
        if (remainingAmount > 0) {
            gameToken.safeTransfer(address(prizePool), remainingAmount);
        }

        emit BetSettled(betId, bet.player, won, payout, randomWord);
    }

    /**
     * @notice Cancel an unfulfilled bet (timeout protection)
     * @param betId ID of the bet to cancel
     */
    function cancelUnfulfilled(uint256 betId) external override nonReentrant {
        Bet storage bet = bets[betId];
        
        if (bet.player == address(0)) revert BetNotFound();
        if (bet.settled) revert BetAlreadySettled();
        if (bet.player != msg.sender && !hasRole(GAME_ADMIN_ROLE, msg.sender)) {
            revert NotBetOwner();
        }
        if (block.number < bet.blockNumber + TIMEOUT_BLOCKS) revert TooEarlyToCancel();

        // Calculate refund amount
        uint256 refundAmount = uint256(bet.amount);
        uint256 potentialPayout = refundAmount * 2;

        // Update exposure
        totalOpenExposure -= potentialPayout;

        // Mark as settled to prevent double cancellation
        bet.settled = true;

        // Refund the bet amount
        gameToken.safeTransfer(bet.player, refundAmount);

        emit BetCancelled(betId, bet.player, refundAmount);
    }

    /**
     * @notice Update minimum bet amount
     * @param newMinBet New minimum bet amount
     */
    function setMinBet(uint256 newMinBet) external onlyRole(GAME_ADMIN_ROLE) {
        if (newMinBet == 0 || newMinBet > maxBet) revert InvalidBetAmount();
        minBet = newMinBet;
        emit MinBetUpdated(newMinBet);
    }

    /**
     * @notice Update maximum bet amount
     * @param newMaxBet New maximum bet amount
     */
    function setMaxBet(uint256 newMaxBet) external onlyRole(GAME_ADMIN_ROLE) {
        if (newMaxBet == 0 || newMaxBet < minBet) revert InvalidBetAmount();
        maxBet = newMaxBet;
        emit MaxBetUpdated(newMaxBet);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Emergency withdrawal of stuck tokens (only when paused)
     * @param to Address to send tokens to
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        
        gameToken.safeTransfer(to, amount);
    }

    /**
     * @notice Get bet information
     * @param betId ID of the bet
     * @return Bet information
     */
    function getBet(uint256 betId) external view override returns (Bet memory) {
        return bets[betId];
    }

    /**
     * @notice Get player's bet history
     * @param player Player address
     * @return Array of bet IDs
     */
    function getPlayerBets(address player) external view returns (uint256[] memory) {
        return playerBets[player];
    }

    /**
     * @notice Get player's recent bets
     * @param player Player address
     * @param limit Maximum number of bets to return
     * @return Array of bet IDs (most recent first)
     */
    function getPlayerRecentBets(address player, uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory allBets = playerBets[player];
        uint256 length = allBets.length;
        uint256 returnLength = length > limit ? limit : length;
        
        uint256[] memory recentBets = new uint256[](returnLength);
        for (uint256 i = 0; i < returnLength; i++) {
            recentBets[i] = allBets[length - 1 - i];
        }
        
        return recentBets;
    }

    /**
     * @notice Get the minimum bet amount
     * @return Minimum bet amount
     */
    function getMinBet() external view override returns (uint256) {
        return minBet;
    }

    /**
     * @notice Get the maximum bet amount
     * @return Maximum bet amount
     */
    function getMaxBet() external view override returns (uint256) {
        return maxBet;
    }

    /**
     * @notice Get total open exposure
     * @return Total open exposure amount
     */
    function getTotalOpenExposure() external view override returns (uint256) {
        return totalOpenExposure;
    }

    /**
     * @notice Get game statistics
     * @return totalBetsPlaced Total number of bets placed
     * @return totalVolumeTraded Total volume traded
     * @return currentOpenExposure Current open exposure
     * @return vaultBalance Current vault balance
     */
    function getGameStats() external view returns (
        uint256 totalBetsPlaced,
        uint256 totalVolumeTraded,
        uint256 currentOpenExposure,
        uint256 vaultBalance
    ) {
        totalBetsPlaced = totalBets;
        totalVolumeTraded = totalVolume;
        currentOpenExposure = totalOpenExposure;
        vaultBalance = prizePool.getAvailableBalance();
    }

    /**
     * @notice Check if a bet can be cancelled
     * @param betId ID of the bet
     * @return Whether the bet can be cancelled
     */
    function canCancelBet(uint256 betId) external view returns (bool) {
        Bet memory bet = bets[betId];
        return !bet.settled && block.number >= bet.blockNumber + TIMEOUT_BLOCKS;
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}