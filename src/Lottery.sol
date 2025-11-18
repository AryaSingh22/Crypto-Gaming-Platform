// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./interfaces/IPrizePool.sol";
import "./GamePass.sol";

/**
 * @title Lottery
 * @notice Weekly lottery system with VRF-powered fair draws
 * @dev Users buy tickets with GAME tokens, winners determined by VRF randomness
 */
contract Lottery is VRFConsumerBaseV2, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for lottery administration
    bytes32 public constant LOTTERY_ADMIN_ROLE = keccak256("LOTTERY_ADMIN_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice VRF Coordinator interface
    VRFCoordinatorV2Interface private immutable vrfCoordinator;

    /// @notice VRF subscription ID
    uint64 private immutable subscriptionId;

    /// @notice VRF key hash (gas lane)
    bytes32 private immutable keyHash;

    /// @notice VRF request confirmations
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @notice VRF callback gas limit
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;

    /// @notice Number of random words to request
    uint32 private constant NUM_WORDS = 1;

    /// @notice Lottery duration (1 week)
    uint256 public constant LOTTERY_DURATION = 7 days;

    /// @notice Maximum tickets per user per round
    uint256 public constant MAX_TICKETS_PER_USER = 100;

    /// @notice Game token for ticket purchases
    IERC20 public immutable gameToken;

    /// @notice Prize pool for funding prizes
    IPrizePool public immutable prizePool;

    /// @notice Game pass contract for bonus entries
    GamePass public immutable gamePass;

    /// @notice Ticket price in GAME tokens
    uint256 public ticketPrice;

    /// @notice Current lottery round
    uint256 public currentRound;

    /// @notice Prize distribution percentages (basis points)
    struct PrizeDistribution {
        uint16 firstPlace;    // Winner 1 percentage
        uint16 secondPlace;   // Winner 2 percentage
        uint16 thirdPlace;    // Winner 3 percentage
        uint16 prizePool;     // Back to prize pool
        uint16 treasury;      // Platform fee
    }

    /// @notice Current prize distribution
    PrizeDistribution public prizeDistribution;

    /// @notice Lottery round information
    struct LotteryRound {
        uint256 startTime;
        uint256 endTime;
        uint256 totalTickets;
        uint256 prizeAmount;
        address[] winners;
        uint256[] winnerPrizes;
        bool drawn;
        bool prizesClaimed;
        uint256 vrfRequestId;
    }

    /// @notice Mapping from round to lottery info
    mapping(uint256 => LotteryRound) public lotteryRounds;

    /// @notice Mapping from round to user ticket count
    mapping(uint256 => mapping(address => uint256)) public userTickets;

    /// @notice Mapping from round to ticket owners
    mapping(uint256 => address[]) public ticketOwners;

    /// @notice Mapping from VRF request ID to round
    mapping(uint256 => uint256) private vrfRequestToRound;

    /// @notice Treasury address
    address public treasury;

    /// @notice Events
    event LotteryStarted(uint256 indexed round, uint256 startTime, uint256 endTime);
    event TicketPurchased(uint256 indexed round, address indexed buyer, uint256 tickets, uint256 cost);
    event LotteryDrawn(uint256 indexed round, uint256 vrfRequestId);
    event WinnersSelected(uint256 indexed round, address[] winners, uint256[] prizes);
    event PrizeClaimed(uint256 indexed round, address indexed winner, uint256 amount);
    event TicketPriceUpdated(uint256 newPrice);
    event PrizeDistributionUpdated(PrizeDistribution newDistribution);

    /// @notice Custom errors
    error LotteryNotActive();
    error LotteryEnded();
    error InvalidTicketCount();
    error ExceedsMaxTickets();
    error LotteryNotEnded();
    error AlreadyDrawn();
    error NotWinner();
    error PrizeAlreadyClaimed();
    error InvalidPrizeDistribution();
    error ZeroAddress();

    /**
     * @notice Constructor
     * @param vrfCoordinatorAddress Chainlink VRF Coordinator
     * @param subscriptionId_ VRF subscription ID
     * @param keyHash_ VRF key hash
     * @param gameTokenAddress Game token address
     * @param prizePoolAddress Prize pool address
     * @param gamePassAddress Game pass address
     * @param treasuryAddress Treasury address
     * @param initialTicketPrice Initial ticket price
     * @param admin Admin address
     */
    constructor(
        address vrfCoordinatorAddress,
        uint64 subscriptionId_,
        bytes32 keyHash_,
        address gameTokenAddress,
        address prizePoolAddress,
        address gamePassAddress,
        address treasuryAddress,
        uint256 initialTicketPrice,
        address admin
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) {
        if (
            vrfCoordinatorAddress == address(0) ||
            gameTokenAddress == address(0) ||
            prizePoolAddress == address(0) ||
            gamePassAddress == address(0) ||
            treasuryAddress == address(0) ||
            admin == address(0)
        ) revert ZeroAddress();

        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        subscriptionId = subscriptionId_;
        keyHash = keyHash_;
        gameToken = IERC20(gameTokenAddress);
        prizePool = IPrizePool(prizePoolAddress);
        gamePass = GamePass(gamePassAddress);
        treasury = treasuryAddress;
        ticketPrice = initialTicketPrice;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(LOTTERY_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Set default prize distribution (50%, 30%, 20%, 0%, 0%)
        prizeDistribution = PrizeDistribution({
            firstPlace: 5000,
            secondPlace: 3000, 
            thirdPlace: 2000,
            prizePool: 0,
            treasury: 0
        });

        // Start first lottery
        _startNewLottery();
    }

    /**
     * @notice Buy lottery tickets
     * @param ticketCount Number of tickets to buy
     */
    function buyTickets(uint256 ticketCount) external whenNotPaused nonReentrant {
        if (ticketCount == 0) revert InvalidTicketCount();
        
        LotteryRound storage round = lotteryRounds[currentRound];
        if (block.timestamp >= round.endTime) revert LotteryEnded();
        
        uint256 userCurrentTickets = userTickets[currentRound][msg.sender];
        if (userCurrentTickets + ticketCount > MAX_TICKETS_PER_USER) {
            revert ExceedsMaxTickets();
        }

        uint256 totalCost = ticketCount * ticketPrice;
        
        // Apply discount for NFT pass holders
        uint256 discount = _getTicketDiscount(msg.sender);
        if (discount > 0) {
            totalCost = (totalCost * (10000 - discount)) / 10000;
        }

        // Transfer payment
        gameToken.safeTransferFrom(msg.sender, address(this), totalCost);

        // Record tickets
        userTickets[currentRound][msg.sender] += ticketCount;
        
        // Add ticket entries
        for (uint256 i = 0; i < ticketCount; i++) {
            ticketOwners[currentRound].push(msg.sender);
        }
        
        round.totalTickets += ticketCount;
        round.prizeAmount += totalCost;

        // Add bonus tickets for higher tier NFT holders
        uint256 bonusTickets = _getBonusTickets(msg.sender, ticketCount);
        if (bonusTickets > 0) {
            for (uint256 i = 0; i < bonusTickets; i++) {
                ticketOwners[currentRound].push(msg.sender);
            }
            round.totalTickets += bonusTickets;
        }

        emit TicketPurchased(currentRound, msg.sender, ticketCount, totalCost);
    }

    /**
     * @notice Draw lottery winners (admin only)
     */
    function drawLottery() external onlyRole(LOTTERY_ADMIN_ROLE) {
        LotteryRound storage round = lotteryRounds[currentRound];
        
        if (block.timestamp < round.endTime) revert LotteryNotEnded();
        if (round.drawn) revert AlreadyDrawn();
        if (round.totalTickets == 0) {
            // No tickets sold, start new round
            _startNewLottery();
            return;
        }

        // Request VRF randomness
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        round.vrfRequestId = requestId;
        vrfRequestToRound[requestId] = currentRound;

        emit LotteryDrawn(currentRound, requestId);
    }

    /**
     * @notice VRF callback to select winners
     * @param requestId VRF request ID
     * @param randomWords Random words from VRF
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 roundId = vrfRequestToRound[requestId];
        LotteryRound storage round = lotteryRounds[roundId];
        
        if (round.drawn) return; // Already processed

        uint256 randomWord = randomWords[0];
        _selectWinners(roundId, randomWord);
        
        round.drawn = true;
        
        // Start next lottery
        _startNewLottery();
    }

    /**
     * @notice Claim lottery prize
     * @param roundId Round to claim prize from
     */
    function claimPrize(uint256 roundId) external nonReentrant {
        LotteryRound storage round = lotteryRounds[roundId];
        
        if (!round.drawn) revert LotteryNotEnded();
        
        // Find winner index
        uint256 winnerIndex = type(uint256).max;
        for (uint256 i = 0; i < round.winners.length; i++) {
            if (round.winners[i] == msg.sender) {
                winnerIndex = i;
                break;
            }
        }
        
        if (winnerIndex == type(uint256).max) revert NotWinner();
        
        uint256 prizeAmount = round.winnerPrizes[winnerIndex];
        if (prizeAmount == 0) revert PrizeAlreadyClaimed();
        
        // Mark as claimed
        round.winnerPrizes[winnerIndex] = 0;
        
        // Transfer prize
        gameToken.safeTransfer(msg.sender, prizeAmount);
        
        emit PrizeClaimed(roundId, msg.sender, prizeAmount);
    }

    /**
     * @notice Set ticket price
     * @param newPrice New ticket price
     */
    function setTicketPrice(uint256 newPrice) external onlyRole(LOTTERY_ADMIN_ROLE) {
        ticketPrice = newPrice;
        emit TicketPriceUpdated(newPrice);
    }

    /**
     * @notice Set prize distribution
     * @param newDistribution New prize distribution
     */
    function setPrizeDistribution(PrizeDistribution calldata newDistribution) 
        external 
        onlyRole(LOTTERY_ADMIN_ROLE) 
    {
        if (newDistribution.firstPlace + newDistribution.secondPlace + 
            newDistribution.thirdPlace + newDistribution.prizePool + 
            newDistribution.treasury != 10000) {
            revert InvalidPrizeDistribution();
        }
        
        prizeDistribution = newDistribution;
        emit PrizeDistributionUpdated(newDistribution);
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
     * @notice Get current lottery info
     * @return Current lottery round information
     */
    function getCurrentLottery() external view returns (LotteryRound memory) {
        return lotteryRounds[currentRound];
    }

    /**
     * @notice Get user ticket count for current round
     * @param user User address
     * @return Number of tickets owned
     */
    function getUserTickets(address user) external view returns (uint256) {
        return userTickets[currentRound][user];
    }

    /**
     * @notice Get lottery round winners
     * @param roundId Round ID
     * @return winners Winner addresses
     * @return prizes Prize amounts
     */
    function getRoundWinners(uint256 roundId) 
        external 
        view 
        returns (address[] memory winners, uint256[] memory prizes) 
    {
        LotteryRound storage round = lotteryRounds[roundId];
        return (round.winners, round.winnerPrizes);
    }

    /**
     * @notice Start new lottery round
     */
    function _startNewLottery() internal {
        currentRound++;
        
        LotteryRound storage newRound = lotteryRounds[currentRound];
        newRound.startTime = block.timestamp;
        newRound.endTime = block.timestamp + LOTTERY_DURATION;
        
        emit LotteryStarted(currentRound, newRound.startTime, newRound.endTime);
    }

    /**
     * @notice Select winners from ticket holders
     * @param roundId Round ID
     * @param randomWord Random number from VRF
     */
    function _selectWinners(uint256 roundId, uint256 randomWord) internal {
        LotteryRound storage round = lotteryRounds[roundId];
        address[] storage tickets = ticketOwners[roundId];
        
        if (tickets.length == 0) return;
        
        // Calculate number of winners (max 3)
        uint256 numWinners = tickets.length >= 3 ? 3 : tickets.length;
        
        round.winners = new address[](numWinners);
        round.winnerPrizes = new uint256[](numWinners);
        
        // Track selected indices to avoid duplicates
        uint256[] memory selectedIndices = new uint256[](numWinners);
        uint256 nonce = 0;
        
        for (uint256 i = 0; i < numWinners; i++) {
            uint256 winnerIndex;
            bool isUnique;
            
            // Find unique winner
            do {
                winnerIndex = uint256(keccak256(abi.encode(randomWord, nonce))) % tickets.length;
                nonce++;
                
                // Check if this index was already selected
                isUnique = true;
                for (uint256 j = 0; j < i; j++) {
                    if (selectedIndices[j] == winnerIndex) {
                        isUnique = false;
                        break;
                    }
                }
            } while (!isUnique && nonce < 1000); // Prevent infinite loop
            
            selectedIndices[i] = winnerIndex;
            address winner = tickets[winnerIndex];
            round.winners[i] = winner;
            
            // Calculate prize amount
            uint256 prizePercentage;
            if (i == 0) prizePercentage = prizeDistribution.firstPlace;
            else if (i == 1) prizePercentage = prizeDistribution.secondPlace;
            else prizePercentage = prizeDistribution.thirdPlace;
            
            uint256 prizeAmount = (round.prizeAmount * prizePercentage) / 10000;
            round.winnerPrizes[i] = prizeAmount;
        }
        
        // Distribute remaining funds
        uint256 prizePoolShare = (round.prizeAmount * prizeDistribution.prizePool) / 10000;
        uint256 treasuryShare = (round.prizeAmount * prizeDistribution.treasury) / 10000;
        
        if (prizePoolShare > 0) {
            gameToken.safeTransfer(address(prizePool), prizePoolShare);
        }
        
        if (treasuryShare > 0) {
            gameToken.safeTransfer(treasury, treasuryShare);
        }
        
        emit WinnersSelected(roundId, round.winners, round.winnerPrizes);
    }

    /**
     * @notice Get ticket discount based on NFT pass tier
     * @param user User address
     * @return Discount in basis points
     */
    function _getTicketDiscount(address user) internal view returns (uint256) {
        if (!gamePass.hasPass(user)) return 0;
        
        GamePass.Tier highestTier = gamePass.getHighestTier(user);
        
        if (highestTier == GamePass.Tier.Gold) return 500;      // 5% discount
        if (highestTier == GamePass.Tier.Silver) return 300;    // 3% discount
        if (highestTier == GamePass.Tier.Bronze) return 100;    // 1% discount
        
        return 0;
    }

    /**
     * @notice Get bonus tickets based on NFT pass tier
     * @param user User address
     * @param ticketCount Purchased ticket count
     * @return Number of bonus tickets
     */
    function _getBonusTickets(address user, uint256 ticketCount) internal view returns (uint256) {
        if (!gamePass.hasPass(user)) return 0;
        
        GamePass.Tier highestTier = gamePass.getHighestTier(user);
        
        if (highestTier == GamePass.Tier.Gold) {
            return ticketCount / 5;  // 1 bonus per 5 tickets
        }
        if (highestTier == GamePass.Tier.Silver) {
            return ticketCount / 10; // 1 bonus per 10 tickets
        }
        
        return 0; // Bronze gets discount but no bonus tickets
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}