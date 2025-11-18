// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./GamePass.sol";

/**
 * @title PvPBetting
 * @notice Peer-to-peer betting system where users can create and accept bets
 * @dev Uses escrow system and VRF for fair outcomes in skill-agnostic bets
 */
contract PvPBetting is VRFConsumerBaseV2, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for betting administration
    bytes32 public constant BETTING_ADMIN_ROLE = keccak256("BETTING_ADMIN_ROLE");
    
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
    uint32 private constant CALLBACK_GAS_LIMIT = 200000;

    /// @notice Number of random words to request
    uint32 private constant NUM_WORDS = 1;

    /// @notice Bet expiration time (24 hours)
    uint256 public constant BET_EXPIRATION = 24 hours;

    /// @notice Dispute resolution time (1 hour)
    uint256 public constant DISPUTE_WINDOW = 1 hours;

    /// @notice Game token
    IERC20 public immutable gameToken;

    /// @notice Game pass contract
    GamePass public immutable gamePass;

    /// @notice Treasury for fee collection
    address public treasury;

    /// @notice Platform fee in basis points
    uint16 public platformFeeBps;

    /// @notice Minimum bet amount
    uint256 public minBetAmount;

    /// @notice Maximum bet amount
    uint256 public maxBetAmount;

    /// @notice Bet types
    enum BetType {
        CoinFlip,      // VRF-determined outcome
        SkillBased,    // Off-chain verified skills
        CustomProp     // Custom proposition between users
    }

    /// @notice Bet status
    enum BetStatus {
        Open,          // Waiting for opponent
        Accepted,      // Opponent found, game in progress
        WaitingResult, // Waiting for outcome/verification
        Completed,     // Winner determined
        Cancelled,     // Bet cancelled
        Disputed       // Under dispute resolution
    }

    /// @notice Bet information
    struct Bet {
        uint256 id;
        address creator;
        address opponent;
        uint256 amount;
        BetType betType;
        BetStatus status;
        string description;
        bytes32 propositionHash; // For custom props
        address winner;
        uint256 createdAt;
        uint256 expiresAt;
        uint256 vrfRequestId;
        bool creatorSide;       // For coin flip: true = heads, false = tails
        bool opponentSide;      // For coin flip: true = heads, false = tails
        bytes32 resultHash;     // For skill-based verification
        uint256 disputeDeadline;
    }

    /// @notice Next bet ID
    uint256 public nextBetId;

    /// @notice Mapping from bet ID to bet info
    mapping(uint256 => Bet) public bets;

    /// @notice Mapping from VRF request to bet ID
    mapping(uint256 => uint256) private vrfRequestToBet;

    /// @notice Mapping from user to active bet count
    mapping(address => uint256) public userActiveBets;

    /// @notice Maximum active bets per user
    uint256 public maxActiveBetsPerUser;

    /// @notice Trusted result providers for skill-based games
    mapping(address => bool) public trustedProviders;

    /// @notice Events
    event BetCreated(
        uint256 indexed betId,
        address indexed creator,
        uint256 amount,
        BetType betType,
        string description
    );
    
    event BetAccepted(uint256 indexed betId, address indexed opponent);
    event BetCompleted(uint256 indexed betId, address indexed winner, uint256 payout);
    event BetCancelled(uint256 indexed betId, address indexed canceller);
    event BetDisputed(uint256 indexed betId, address indexed disputer);
    event ResultSubmitted(uint256 indexed betId, bytes32 resultHash, address provider);
    event PlatformFeeUpdated(uint16 newFeeBps);
    event BetLimitsUpdated(uint256 minAmount, uint256 maxAmount);

    /// @notice Custom errors
    error InvalidBetAmount();
    error InvalidBetType();
    error BetNotFound();
    error BetNotOpen();
    error CannotBetAgainstSelf();
    error BetExpired();
    error BetNotAccepted();
    error BetAlreadyCompleted();
    error NotBetParticipant();
    error DisputeWindowClosed();
    error NotTrustedProvider();
    error TooManyActiveBets();
    error InsufficientFunds();
    error ZeroAddress();

    /**
     * @notice Constructor
     * @param vrfCoordinatorAddress Chainlink VRF Coordinator
     * @param subscriptionId_ VRF subscription ID
     * @param keyHash_ VRF key hash
     * @param gameTokenAddress Game token address
     * @param gamePassAddress Game pass address
     * @param treasuryAddress Treasury address
     * @param minBetAmount_ Minimum bet amount
     * @param maxBetAmount_ Maximum bet amount
     * @param admin Admin address
     */
    constructor(
        address vrfCoordinatorAddress,
        uint64 subscriptionId_,
        bytes32 keyHash_,
        address gameTokenAddress,
        address gamePassAddress,
        address treasuryAddress,
        uint256 minBetAmount_,
        uint256 maxBetAmount_,
        address admin
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) {
        if (
            vrfCoordinatorAddress == address(0) ||
            gameTokenAddress == address(0) ||
            gamePassAddress == address(0) ||
            treasuryAddress == address(0) ||
            admin == address(0)
        ) revert ZeroAddress();

        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        subscriptionId = subscriptionId_;
        keyHash = keyHash_;
        gameToken = IERC20(gameTokenAddress);
        gamePass = GamePass(gamePassAddress);
        treasury = treasuryAddress;

        // Set default values
        platformFeeBps = 250; // 2.5%
        minBetAmount = minBetAmount_;
        maxBetAmount = maxBetAmount_;
        maxActiveBetsPerUser = 10;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BETTING_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Start bet IDs at 1
        nextBetId = 1;
    }

    /**
     * @notice Create a new bet
     * @param amount Bet amount in GAME tokens
     * @param betType Type of bet
     * @param description Bet description
     * @param propositionHash Hash of custom proposition (for custom bets)
     * @param creatorSide Creator's choice for coin flip (true = heads)
     */
    function createBet(
        uint256 amount,
        BetType betType,
        string calldata description,
        bytes32 propositionHash,
        bool creatorSide
    ) external whenNotPaused nonReentrant {
        if (!gamePass.hasPass(msg.sender)) revert NotBetParticipant();
        if (amount < minBetAmount || amount > maxBetAmount) revert InvalidBetAmount();
        if (userActiveBets[msg.sender] >= maxActiveBetsPerUser) revert TooManyActiveBets();

        // Transfer bet amount to escrow
        gameToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 betId = nextBetId++;
        
        bets[betId] = Bet({
            id: betId,
            creator: msg.sender,
            opponent: address(0),
            amount: amount,
            betType: betType,
            status: BetStatus.Open,
            description: description,
            propositionHash: propositionHash,
            winner: address(0),
            createdAt: block.timestamp,
            expiresAt: block.timestamp + BET_EXPIRATION,
            vrfRequestId: 0,
            creatorSide: creatorSide,
            opponentSide: false,  // Initialize to default value
            resultHash: bytes32(0),
            disputeDeadline: 0
        });

        userActiveBets[msg.sender]++;

        emit BetCreated(betId, msg.sender, amount, betType, description);
    }

    /**
     * @notice Accept an open bet
     * @param betId Bet ID to accept
     * @param opponentSide Opponent's choice for coin flip (if applicable)
     */
    function acceptBet(uint256 betId, bool opponentSide) external whenNotPaused nonReentrant {
        Bet storage bet = bets[betId];
        
        if (bet.creator == address(0)) revert BetNotFound();
        if (bet.status != BetStatus.Open) revert BetNotOpen();
        if (bet.creator == msg.sender) revert CannotBetAgainstSelf();
        if (block.timestamp >= bet.expiresAt) revert BetExpired();
        if (!gamePass.hasPass(msg.sender)) revert NotBetParticipant();
        if (userActiveBets[msg.sender] >= maxActiveBetsPerUser) revert TooManyActiveBets();

        // Transfer opponent's bet amount to escrow
        gameToken.safeTransferFrom(msg.sender, address(this), bet.amount);

        bet.opponent = msg.sender;
        bet.opponentSide = opponentSide;  // Store opponent's side choice
        bet.status = BetStatus.Accepted;
        userActiveBets[msg.sender]++;

        emit BetAccepted(betId, msg.sender);

        // Auto-resolve coin flip bets
        if (bet.betType == BetType.CoinFlip) {
            _requestVRFForBet(betId);
        } else {
            // For skill-based and custom bets, wait for result submission
            bet.status = BetStatus.WaitingResult;
            bet.disputeDeadline = block.timestamp + DISPUTE_WINDOW;
        }
    }

    /**
     * @notice Cancel an open bet
     * @param betId Bet ID to cancel
     */
    function cancelBet(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        
        if (bet.creator == address(0)) revert BetNotFound();
        if (bet.creator != msg.sender) revert NotBetParticipant();
        if (bet.status != BetStatus.Open) revert BetNotOpen();

        bet.status = BetStatus.Cancelled;
        userActiveBets[msg.sender]--;

        // Refund creator
        gameToken.safeTransfer(bet.creator, bet.amount);

        emit BetCancelled(betId, msg.sender);
    }

    /**
     * @notice Submit result for skill-based or custom bets
     * @param betId Bet ID
     * @param resultHash Hash of the result
     * @param winner Address of the winner
     */
    function submitResult(
        uint256 betId, 
        bytes32 resultHash, 
        address winner
    ) external {
        if (!trustedProviders[msg.sender]) revert NotTrustedProvider();
        
        Bet storage bet = bets[betId];
        
        if (bet.creator == address(0)) revert BetNotFound();
        if (bet.status != BetStatus.WaitingResult) revert BetNotAccepted();
        if (winner != bet.creator && winner != bet.opponent && winner != address(0)) {
            revert NotBetParticipant();
        }

        bet.resultHash = resultHash;
        bet.winner = winner;
        bet.status = BetStatus.Completed;

        _distributePayout(betId);

        emit ResultSubmitted(betId, resultHash, msg.sender);
    }

    /**
     * @notice Dispute a bet result
     * @param betId Bet ID to dispute
     */
    function disputeBet(uint256 betId) external {
        Bet storage bet = bets[betId];
        
        if (bet.creator == address(0)) revert BetNotFound();
        if (msg.sender != bet.creator && msg.sender != bet.opponent) revert NotBetParticipant();
        if (bet.status != BetStatus.Completed) revert BetAlreadyCompleted();
        if (block.timestamp > bet.disputeDeadline) revert DisputeWindowClosed();

        bet.status = BetStatus.Disputed;

        emit BetDisputed(betId, msg.sender);
    }

    /**
     * @notice Resolve disputed bet (admin only)
     * @param betId Bet ID
     * @param winner Winner address
     */
    function resolveDispute(uint256 betId, address winner) 
        external 
        onlyRole(BETTING_ADMIN_ROLE) 
    {
        Bet storage bet = bets[betId];
        
        if (bet.creator == address(0)) revert BetNotFound();
        if (bet.status != BetStatus.Disputed) revert BetNotAccepted();
        if (winner != bet.creator && winner != bet.opponent && winner != address(0)) {
            revert NotBetParticipant();
        }

        bet.winner = winner;
        bet.status = BetStatus.Completed;

        _distributePayout(betId);
    }

    /**
     * @notice Set platform fee
     * @param newFeeBps New fee in basis points
     */
    function setPlatformFee(uint16 newFeeBps) external onlyRole(BETTING_ADMIN_ROLE) {
        require(newFeeBps <= 1000, "Fee too high"); // Max 10%
        platformFeeBps = newFeeBps;
        emit PlatformFeeUpdated(newFeeBps);
    }

    /**
     * @notice Set bet amount limits
     * @param newMinAmount New minimum bet amount
     * @param newMaxAmount New maximum bet amount
     */
    function setBetLimits(uint256 newMinAmount, uint256 newMaxAmount) 
        external 
        onlyRole(BETTING_ADMIN_ROLE) 
    {
        require(newMinAmount < newMaxAmount, "Invalid limits");
        minBetAmount = newMinAmount;
        maxBetAmount = newMaxAmount;
        emit BetLimitsUpdated(newMinAmount, newMaxAmount);
    }

    /**
     * @notice Set maximum active bets per user
     * @param newMaxBets New maximum
     */
    function setMaxActiveBets(uint256 newMaxBets) external onlyRole(BETTING_ADMIN_ROLE) {
        maxActiveBetsPerUser = newMaxBets;
    }

    /**
     * @notice Add/remove trusted result provider
     * @param provider Provider address
     * @param trusted Whether provider is trusted
     */
    function setTrustedProvider(address provider, bool trusted) 
        external 
        onlyRole(BETTING_ADMIN_ROLE) 
    {
        trustedProviders[provider] = trusted;
    }

    /**
     * @notice Set treasury address
     * @param newTreasury New treasury
     */
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
    }

    /**
     * @notice Get total number of bets created
     * @return Total number of bets
     */
    function totalBets() external view returns (uint256) {
        return nextBetId - 1;
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
     * @notice Get bet information
     * @param betId Bet ID
     * @return Bet information
     */
    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    /**
     * @notice Get user's active bet IDs
     * @param user User address
     * @return Array of active bet IDs
     */
    function getUserActiveBets(address user) external view returns (uint256[] memory) {
        uint256[] memory activeBets = new uint256[](userActiveBets[user]);
        uint256 index = 0;
        
        for (uint256 i = 1; i < nextBetId; i++) {
            Bet storage bet = bets[i];
            if ((bet.creator == user || bet.opponent == user) && 
                bet.status != BetStatus.Completed && 
                bet.status != BetStatus.Cancelled) {
                activeBets[index] = i;
                index++;
            }
        }
        
        return activeBets;
    }

    /**
     * @notice Request VRF for coin flip bet
     * @param betId Bet ID
     */
    function _requestVRFForBet(uint256 betId) internal {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        bets[betId].vrfRequestId = requestId;
        bets[betId].status = BetStatus.WaitingResult;
        vrfRequestToBet[requestId] = betId;
    }

    /**
     * @notice VRF callback for coin flip resolution
     * @param requestId VRF request ID
     * @param randomWords Random words
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 betId = vrfRequestToBet[requestId];
        Bet storage bet = bets[betId];
        
        if (bet.status != BetStatus.WaitingResult) return;

        uint256 randomWord = randomWords[0];
        bool outcome = (randomWord % 2) == 0; // 0 = heads, 1 = tails
        
        // Determine winner based on creator's choice
        address winner;
        if (bet.creatorSide == outcome) {
            winner = bet.creator;
        } else {
            winner = bet.opponent;
        }

        bet.winner = winner;
        bet.status = BetStatus.Completed;

        _distributePayout(betId);
    }

    /**
     * @notice Distribute payout to winner
     * @param betId Bet ID
     */
    function _distributePayout(uint256 betId) internal {
        Bet storage bet = bets[betId];
        
        uint256 totalPot = bet.amount * 2;
        uint256 platformFee = (totalPot * platformFeeBps) / 10000;
        uint256 payout = totalPot - platformFee;

        // Update active bet counts
        userActiveBets[bet.creator]--;
        userActiveBets[bet.opponent]--;

        if (bet.winner == address(0)) {
            // Draw - refund both parties minus half fee each
            uint256 refund = bet.amount - (platformFee / 2);
            gameToken.safeTransfer(bet.creator, refund);
            gameToken.safeTransfer(bet.opponent, refund);
        } else {
            // Winner takes all minus platform fee
            gameToken.safeTransfer(bet.winner, payout);
        }

        // Transfer platform fee
        if (platformFee > 0) {
            gameToken.safeTransfer(treasury, platformFee);
        }

        emit BetCompleted(betId, bet.winner, payout);
    }

    /**
     * @notice Get minimum bet amount
     * @return Minimum bet amount
     */
    function getMinBet() external view returns (uint256) {
        return minBetAmount;
    }

    /**
     * @notice Get maximum bet amount
     * @return Maximum bet amount
     */
    function getMaxBet() external view returns (uint256) {
        return maxBetAmount;
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}