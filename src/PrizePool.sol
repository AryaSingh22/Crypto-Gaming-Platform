// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPrizePool.sol";

/**
 * @title PrizePool
 * @notice Vault contract that manages game liquidity, payouts, and fee collection
 * @dev Holds GAME tokens and pays out winnings to players while collecting house fees
 */
contract PrizePool is IPrizePool, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for treasury operations
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Maximum fee in basis points (10%)
    uint16 public constant MAX_FEE_BPS = 1000;

    /// @notice The game token used for payouts
    IERC20 public immutable gameToken;

    /// @notice Treasury address where fees are sent
    address public treasury;

    /// @notice House fee in basis points (100 = 1%)
    uint16 public feeBps;

    /// @notice Mapping of authorized game contracts
    mapping(address => bool) public authorizedGames;

    /// @notice Total fees collected
    uint256 public totalFeesCollected;

    /// @notice Total payouts made
    uint256 public totalPayouts;

    /// @notice Events
    event Deposited(address indexed from, uint256 amount);
    event Payout(address indexed to, uint256 grossWin, uint256 fee, uint256 netWin);
    event FeeUpdated(uint16 newFeeBps);
    event TreasuryUpdated(address indexed newTreasury);
    event GameAuthorized(address indexed game, bool authorized);
    event TreasuryWithdrawal(address indexed to, uint256 amount);
    event EmergencyWithdrawal(address indexed to, uint256 amount);

    /// @notice Custom errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidFee();
    error UnauthorizedGame();
    error InsufficientBalance();
    error TransferFailed();

    /// @notice Modifier to check if caller is an authorized game
    modifier onlyAuthorizedGame() {
        if (!authorizedGames[msg.sender]) revert UnauthorizedGame();
        _;
    }

    /**
     * @notice Constructor
     * @param gameTokenAddress Address of the game token
     * @param treasuryAddress Treasury address for fee collection
     * @param initialFeeBps Initial house fee in basis points
     * @param admin Admin address for role management
     */
    constructor(
        address gameTokenAddress,
        address treasuryAddress,
        uint16 initialFeeBps,
        address admin
    ) {
        if (gameTokenAddress == address(0) || treasuryAddress == address(0) || admin == address(0)) {
            revert ZeroAddress();
        }
        if (initialFeeBps > MAX_FEE_BPS) revert InvalidFee();

        gameToken = IERC20(gameTokenAddress);
        treasury = treasuryAddress;
        feeBps = initialFeeBps;

        // Grant roles to admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(TREASURER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /**
     * @notice Deposit tokens into the prize pool
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external override whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();

        gameToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(msg.sender, amount);
    }

    /**
     * @notice Pay out winnings to a player (called by authorized games only)
     * @param to Address to pay out to
     * @param grossWin Gross winning amount before fees
     */
    function payout(address to, uint256 grossWin) external override onlyAuthorizedGame whenNotPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (grossWin == 0) revert ZeroAmount();

        // Calculate fee and net payout
        uint256 fee = (grossWin * feeBps) / 10000;
        uint256 netWin = grossWin - fee;

        // Check if we have sufficient balance
        uint256 availableBalance = gameToken.balanceOf(address(this));
        if (availableBalance < grossWin) revert InsufficientBalance();

        // Update counters
        totalPayouts += grossWin;
        totalFeesCollected += fee;

        // Transfer net winnings to player
        if (netWin > 0) {
            gameToken.safeTransfer(to, netWin);
        }

        // Transfer fee to treasury
        if (fee > 0) {
            gameToken.safeTransfer(treasury, fee);
        }

        emit Payout(to, grossWin, fee, netWin);
    }

    /**
     * @notice Authorize or deauthorize a game contract
     * @param game Address of the game contract
     * @param allowed Whether the game is authorized
     */
    function authorizeGame(address game, bool allowed) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (game == address(0)) revert ZeroAddress();
        
        authorizedGames[game] = allowed;
        emit GameAuthorized(game, allowed);
    }

    /**
     * @notice Set the house fee in basis points
     * @param bps Fee in basis points (100 = 1%)
     */
    function setFeeBps(uint16 bps) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bps > MAX_FEE_BPS) revert InvalidFee();
        
        feeBps = bps;
        emit FeeUpdated(bps);
    }

    /**
     * @notice Set treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Withdraw tokens from treasury reserves (fees collected)
     * @param amount Amount to withdraw
     */
    function withdrawTreasury(uint256 amount) external onlyRole(TREASURER_ROLE) nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        uint256 balance = gameToken.balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        gameToken.safeTransfer(treasury, amount);
        emit TreasuryWithdrawal(treasury, amount);
    }

    /**
     * @notice Emergency withdrawal (only admin, when paused)
     * @param to Address to withdraw to
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        
        uint256 balance = gameToken.balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        gameToken.safeTransfer(to, amount);
        emit EmergencyWithdrawal(to, amount);
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
     * @notice Get the available balance for payouts
     * @return Available balance
     */
    function getAvailableBalance() external view override returns (uint256) {
        return gameToken.balanceOf(address(this));
    }

    /**
     * @notice Check if a game contract is authorized
     * @param game Address of the game contract
     * @return Whether the game is authorized
     */
    function isGameAuthorized(address game) external view override returns (bool) {
        return authorizedGames[game];
    }

    /**
     * @notice Get current fee percentage
     * @return Fee percentage with 2 decimals (e.g., 250 = 2.50%)
     */
    function getFeePercentage() external view returns (uint256) {
        return (feeBps * 100) / 10000;
    }

    /**
     * @notice Calculate payout details for a given gross win
     * @param grossWin Gross winning amount
     * @return fee House fee amount
     * @return netWin Net payout amount
     */
    function calculatePayout(uint256 grossWin) external view returns (uint256 fee, uint256 netWin) {
        fee = (grossWin * feeBps) / 10000;
        netWin = grossWin - fee;
    }

    /**
     * @notice Get contract statistics
     * @return balance Current contract balance
     * @return totalPayoutsMade Total payouts made
     * @return totalFeesCollected_ Total fees collected
     * @return currentFeeBps Current fee in basis points
     */
    function getStats() external view returns (
        uint256 balance,
        uint256 totalPayoutsMade,
        uint256 totalFeesCollected_,
        uint16 currentFeeBps
    ) {
        balance = gameToken.balanceOf(address(this));
        totalPayoutsMade = totalPayouts;
        totalFeesCollected_ = totalFeesCollected;
        currentFeeBps = feeBps;
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}