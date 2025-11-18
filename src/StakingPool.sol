// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GamePass.sol";

/**
 * @title StakingPool
 * @notice Staking contract where users stake GAME tokens to earn yield from platform revenue
 * @dev Implements time-based rewards with NFT tier multipliers and lock periods
 */
contract StakingPool is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for staking administration
    bytes32 public constant STAKING_ADMIN_ROLE = keccak256("STAKING_ADMIN_ROLE");
    
    /// @notice Role for reward distribution
    bytes32 public constant REWARD_DISTRIBUTOR_ROLE = keccak256("REWARD_DISTRIBUTOR_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Game token for staking and rewards
    IERC20 public immutable gameToken;

    /// @notice Game pass contract for tier multipliers
    GamePass public immutable gamePass;

    /// @notice Lock periods in seconds
    struct LockPeriod {
        uint256 duration;
        uint256 multiplier; // Basis points (10000 = 1x)
        bool active;
    }

    /// @notice Available lock periods
    mapping(uint256 => LockPeriod) public lockPeriods;
    
    /// @notice Number of lock period options
    uint256 public lockPeriodCount;

    /// @notice Staking position information
    struct StakePosition {
        uint256 amount;          // Staked amount
        uint256 lockPeriodId;    // Lock period ID
        uint256 startTime;       // Stake start time
        uint256 unlockTime;      // Unlock time
        uint256 lastRewardTime;  // Last reward calculation time
        uint256 accumulatedRewards; // Accumulated unclaimed rewards
        bool withdrawn;          // Whether position is withdrawn
    }

    /// @notice Mapping from user to position ID to stake position
    mapping(address => mapping(uint256 => StakePosition)) public userStakes;

    /// @notice Mapping from user to position count
    mapping(address => uint256) public userPositionCount;

    /// @notice Total staked amount
    uint256 public totalStaked;

    /// @notice Total distributed rewards
    uint256 public totalRewardsDistributed;

    /// @notice Reward rate per second per token (in wei)
    uint256 public baseRewardRate;

    /// @notice Accumulated reward per share (scaled by 1e18)
    uint256 public accRewardPerShare;

    /// @notice Last reward update time
    uint256 public lastRewardUpdateTime;

    /// @notice Minimum stake amount
    uint256 public minStakeAmount;

    /// @notice Emergency withdrawal penalty (basis points)
    uint16 public emergencyWithdrawalPenalty;

    /// @notice Treasury for penalty collection
    address public treasury;

    /// @notice NFT tier multipliers (basis points, 10000 = 1x)
    mapping(GamePass.Tier => uint256) public tierMultipliers;

    /// @notice Events
    event Staked(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount,
        uint256 lockPeriodId,
        uint256 unlockTime
    );
    
    event Withdrawn(
        address indexed user,
        uint256 indexed positionId,
        uint256 amount,
        uint256 rewards,
        bool emergency
    );
    
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsDistributed(uint256 amount);
    event RewardRateUpdated(uint256 newRate);
    event LockPeriodUpdated(uint256 indexed periodId, uint256 duration, uint256 multiplier, bool active);
    event EmergencyWithdrawalPenaltyUpdated(uint16 newPenalty);

    /// @notice Custom errors
    error ZeroAmount();
    error ZeroAddress();
    error InvalidLockPeriod();
    error StakeNotFound();
    error StakeStillLocked();
    error StakeAlreadyWithdrawn();
    error MinStakeNotMet();
    error InvalidMultiplier();
    error InvalidRewardRate();

    /**
     * @notice Constructor
     * @param gameTokenAddress Game token address
     * @param gamePassAddress Game pass address
     * @param treasuryAddress Treasury address
     * @param admin Admin address
     */
    constructor(
        address gameTokenAddress,
        address gamePassAddress,
        address treasuryAddress,
        address admin
    ) {
        if (
            gameTokenAddress == address(0) ||
            gamePassAddress == address(0) ||
            treasuryAddress == address(0) ||
            admin == address(0)
        ) revert ZeroAddress();

        gameToken = IERC20(gameTokenAddress);
        gamePass = GamePass(gamePassAddress);
        treasury = treasuryAddress;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(STAKING_ADMIN_ROLE, admin);
        _grantRole(REWARD_DISTRIBUTOR_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Set default values
        minStakeAmount = 100e18; // 100 GAME
        emergencyWithdrawalPenalty = 1000; // 10%
        baseRewardRate = 1e15; // ~3.15% APY base rate (1e15 wei per second per token)
        lastRewardUpdateTime = block.timestamp;

        // Set default lock periods
        _initializeLockPeriods();

        // Set default NFT tier multipliers
        tierMultipliers[GamePass.Tier.Bronze] = 10000; // 1.0x
        tierMultipliers[GamePass.Tier.Silver] = 12000; // 1.2x
        tierMultipliers[GamePass.Tier.Gold] = 15000;   // 1.5x
    }

    /**
     * @notice Stake tokens with specified lock period
     * @param amount Amount to stake
     * @param lockPeriodId Lock period ID
     */
    function stake(uint256 amount, uint256 lockPeriodId) external whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (amount < minStakeAmount) revert MinStakeNotMet();
        if (lockPeriodId >= lockPeriodCount || !lockPeriods[lockPeriodId].active) {
            revert InvalidLockPeriod();
        }

        _updateRewards();

        // Transfer tokens to contract
        gameToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 positionId = userPositionCount[msg.sender]++;
        LockPeriod storage lockPeriod = lockPeriods[lockPeriodId];
        
        userStakes[msg.sender][positionId] = StakePosition({
            amount: amount,
            lockPeriodId: lockPeriodId,
            startTime: block.timestamp,
            unlockTime: block.timestamp + lockPeriod.duration,
            lastRewardTime: block.timestamp,
            accumulatedRewards: 0,
            withdrawn: false
        });

        totalStaked += amount;

        emit Staked(msg.sender, positionId, amount, lockPeriodId, block.timestamp + lockPeriod.duration);
    }

    /**
     * @notice Withdraw stake and rewards
     * @param positionId Position ID to withdraw
     */
    function withdraw(uint256 positionId) external nonReentrant {
        StakePosition storage position = userStakes[msg.sender][positionId];
        
        if (position.amount == 0) revert StakeNotFound();
        if (position.withdrawn) revert StakeAlreadyWithdrawn();
        if (block.timestamp < position.unlockTime) revert StakeStillLocked();

        _updateRewards();
        uint256 rewards = _calculatePositionRewards(msg.sender, positionId);
        
        position.withdrawn = true;
        totalStaked -= position.amount;

        // Transfer staked amount back
        gameToken.safeTransfer(msg.sender, position.amount);

        // Transfer rewards if any
        if (rewards > 0) {
            gameToken.safeTransfer(msg.sender, rewards);
        }

        emit Withdrawn(msg.sender, positionId, position.amount, rewards, false);
    }

    /**
     * @notice Emergency withdraw with penalty
     * @param positionId Position ID to withdraw
     */
    function emergencyWithdraw(uint256 positionId) external nonReentrant {
        StakePosition storage position = userStakes[msg.sender][positionId];
        
        if (position.amount == 0) revert StakeNotFound();
        if (position.withdrawn) revert StakeAlreadyWithdrawn();

        _updateRewards();
        uint256 rewards = _calculatePositionRewards(msg.sender, positionId);
        
        position.withdrawn = true;
        totalStaked -= position.amount;

        // Calculate penalty
        uint256 penalty = (position.amount * emergencyWithdrawalPenalty) / 10000;
        uint256 withdrawAmount = position.amount - penalty;

        // Transfer penalized amount
        gameToken.safeTransfer(msg.sender, withdrawAmount);
        
        // Transfer penalty to treasury
        if (penalty > 0) {
            gameToken.safeTransfer(treasury, penalty);
        }

        // Transfer rewards if any (no penalty on rewards)
        if (rewards > 0) {
            gameToken.safeTransfer(msg.sender, rewards);
        }

        emit Withdrawn(msg.sender, positionId, withdrawAmount, rewards, true);
    }

    /**
     * @notice Claim accumulated rewards without withdrawing stake
     * @param positionId Position ID
     */
    function claimRewards(uint256 positionId) external nonReentrant {
        StakePosition storage position = userStakes[msg.sender][positionId];
        
        if (position.amount == 0) revert StakeNotFound();
        if (position.withdrawn) revert StakeAlreadyWithdrawn();

        _updateRewards();
        uint256 rewards = _calculatePositionRewards(msg.sender, positionId);
        
        if (rewards > 0) {
            position.accumulatedRewards = 0;
            position.lastRewardTime = block.timestamp;
            gameToken.safeTransfer(msg.sender, rewards);
            emit RewardsClaimed(msg.sender, rewards);
        }
    }

    /**
     * @notice Distribute rewards to staking pool
     * @param amount Amount of rewards to distribute
     */
    function distributeRewards(uint256 amount) external onlyRole(REWARD_DISTRIBUTOR_ROLE) {
        if (amount == 0) revert ZeroAmount();
        
        gameToken.safeTransferFrom(msg.sender, address(this), amount);
        
        _updateRewards();
        
        if (totalStaked > 0) {
            accRewardPerShare += (amount * 1e18) / totalStaked;
        }
        
        totalRewardsDistributed += amount;
        
        emit RewardsDistributed(amount);
    }

    /**
     * @notice Set base reward rate
     * @param newRate New reward rate per second per token
     */
    function setBaseRewardRate(uint256 newRate) external onlyRole(STAKING_ADMIN_ROLE) {
        _updateRewards();
        baseRewardRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    /**
     * @notice Add or update lock period
     * @param periodId Period ID
     * @param duration Duration in seconds
     * @param multiplier Multiplier in basis points
     * @param active Whether period is active
     */
    function setLockPeriod(
        uint256 periodId,
        uint256 duration,
        uint256 multiplier,
        bool active
    ) external onlyRole(STAKING_ADMIN_ROLE) {
        if (multiplier == 0) revert InvalidMultiplier();
        
        lockPeriods[periodId] = LockPeriod({
            duration: duration,
            multiplier: multiplier,
            active: active
        });
        
        if (periodId >= lockPeriodCount) {
            lockPeriodCount = periodId + 1;
        }
        
        emit LockPeriodUpdated(periodId, duration, multiplier, active);
    }

    /**
     * @notice Set NFT tier multiplier
     * @param tier NFT tier
     * @param multiplier Multiplier in basis points
     */
    function setTierMultiplier(GamePass.Tier tier, uint256 multiplier) 
        external 
        onlyRole(STAKING_ADMIN_ROLE) 
    {
        if (multiplier == 0) revert InvalidMultiplier();
        tierMultipliers[tier] = multiplier;
    }

    /**
     * @notice Set minimum stake amount
     * @param newMinAmount New minimum stake amount
     */
    function setMinStakeAmount(uint256 newMinAmount) external onlyRole(STAKING_ADMIN_ROLE) {
        minStakeAmount = newMinAmount;
    }

    /**
     * @notice Set emergency withdrawal penalty
     * @param newPenalty New penalty in basis points
     */
    function setEmergencyWithdrawalPenalty(uint16 newPenalty) external onlyRole(STAKING_ADMIN_ROLE) {
        require(newPenalty <= 5000, "Penalty too high"); // Max 50%
        emergencyWithdrawalPenalty = newPenalty;
        emit EmergencyWithdrawalPenaltyUpdated(newPenalty);
    }

    /**
     * @notice Set treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Get user's stake position
     * @param user User address
     * @param positionId Position ID
     * @return Stake position information
     */
    function getUserStake(address user, uint256 positionId) 
        external 
        view 
        returns (StakePosition memory) 
    {
        return userStakes[user][positionId];
    }

    /**
     * @notice Get pending rewards for a position
     * @param user User address
     * @param positionId Position ID
     * @return Pending reward amount
     */
    function getPendingRewards(address user, uint256 positionId) 
        external 
        view 
        returns (uint256) 
    {
        return _calculatePositionRewards(user, positionId);
    }

    /**
     * @notice Get user's total staked amount
     * @param user User address
     * @return Total staked amount
     */
    function getUserTotalStaked(address user) external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < userPositionCount[user]; i++) {
            if (!userStakes[user][i].withdrawn) {
                total += userStakes[user][i].amount;
            }
        }
        return total;
    }

    /**
     * @notice Get APY for specific lock period and NFT tier
     * @param lockPeriodId Lock period ID
     * @param nftTier NFT tier (use Bronze if no NFT)
     * @return APY in basis points
     */
    function getAPY(uint256 lockPeriodId, GamePass.Tier nftTier) 
        external 
        view 
        returns (uint256) 
    {
        if (lockPeriodId >= lockPeriodCount) return 0;
        
        uint256 baseAPY = baseRewardRate * 365 days * 10000 / 1e18; // Convert to basis points
        baseAPY = (baseAPY * lockPeriods[lockPeriodId].multiplier) / 10000;
        baseAPY = (baseAPY * tierMultipliers[nftTier]) / 10000;
        
        return baseAPY;
    }

    /**
     * @notice Initialize default lock periods
     */
    function _initializeLockPeriods() internal {
        // No lock period (0.8x multiplier)
        lockPeriods[0] = LockPeriod({
            duration: 0,
            multiplier: 8000,
            active: true
        });
        
        // 30 days (1.0x multiplier)
        lockPeriods[1] = LockPeriod({
            duration: 30 days,
            multiplier: 10000,
            active: true
        });
        
        // 90 days (1.5x multiplier)
        lockPeriods[2] = LockPeriod({
            duration: 90 days,
            multiplier: 15000,
            active: true
        });
        
        // 180 days (2.0x multiplier)
        lockPeriods[3] = LockPeriod({
            duration: 180 days,
            multiplier: 20000,
            active: true
        });
        
        // 365 days (3.0x multiplier)
        lockPeriods[4] = LockPeriod({
            duration: 365 days,
            multiplier: 30000,
            active: true
        });
        
        lockPeriodCount = 5;
    }

    /**
     * @notice Update global reward accounting
     */
    function _updateRewards() internal {
        if (block.timestamp <= lastRewardUpdateTime) return;
        
        if (totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastRewardUpdateTime;
            timeElapsed = timeElapsed * baseRewardRate * totalStaked / 1e18;
            accRewardPerShare += (timeElapsed * 1e18) / totalStaked;
        }
        
        lastRewardUpdateTime = block.timestamp;
    }

    /**
     * @notice Calculate rewards for a specific position
     * @param user User address
     * @param positionId Position ID
     * @return Reward amount
     */
    function _calculatePositionRewards(address user, uint256 positionId) 
        internal 
        view 
        returns (uint256) 
    {
        StakePosition storage position = userStakes[user][positionId];
        if (position.amount == 0 || position.withdrawn) return 0;

        // Calculate time-based rewards
        uint256 timeElapsed = block.timestamp - position.lastRewardTime;
        uint256 baseReward = timeElapsed * baseRewardRate * position.amount / 1e18;

        // Apply lock period multiplier
        LockPeriod storage lockPeriod = lockPeriods[position.lockPeriodId];
        baseReward = (baseReward * lockPeriod.multiplier) / 10000;

        // Apply NFT tier multiplier
        if (gamePass.hasPass(user)) {
            GamePass.Tier userTier = gamePass.getHighestTier(user);
            baseReward = (baseReward * tierMultipliers[userTier]) / 10000;
        }
        
        return position.accumulatedRewards + baseReward;
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}