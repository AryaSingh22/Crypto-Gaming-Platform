// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IMonitoringSystem.sol";

/**
 * @title TournamentSystem
 * @dev Advanced tournament and guild system with skill-based games and NFT team ownership
 */
contract TournamentSystem is ERC721, ERC721Enumerable, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant TOURNAMENT_ADMIN_ROLE = keccak256("TOURNAMENT_ADMIN_ROLE");
    bytes32 public constant GAME_OPERATOR_ROLE = keccak256("GAME_OPERATOR_ROLE");

    enum TournamentStatus {
        Created,
        RegistrationOpen,
        InProgress,
        Completed,
        Cancelled
    }

    enum GameType {
        CoinFlip,
        Poker,
        Chess,
        RockPaperScissors,
        Custom
    }

    struct Tournament {
        uint256 id;
        string name;
        string description;
        GameType gameType;
        uint256 entryFee;
        uint256 maxParticipants;
        uint256 startTime;
        uint256 endTime;
        TournamentStatus status;
        address[] participants;
        mapping(address => bool) isParticipant;
        uint256 prizePool;
        address winner;
        uint256[] rankings;
        mapping(address => uint256) playerScores;
        bool isGuildTournament;
        uint256 requiredGuildLevel;
    }

    struct Guild {
        uint256 id;
        string name;
        string description;
        address owner;
        address[] members;
        mapping(address => bool) isMember;
        uint256 level;
        uint256 experience;
        uint256 totalTournamentWins;
        bool isActive;
        uint256 memberLimit;
        uint256 creationTime;
    }

    struct Player {
        address playerAddress;
        uint256 totalWins;
        uint256 totalLosses;
        uint256 skillRating;
        uint256 tournamentPoints;
        uint256 guildId;
        mapping(GameType => uint256) gameSpecificRatings;
        uint256[] achievementIds;
    }

    // State variables
    IERC20 public gameToken;
    IMonitoringSystem public monitoringSystem;
    
    uint256 public tournamentCount;
    uint256 public guildCount;
    uint256 public nextTokenId = 1;
    
    mapping(uint256 => Tournament) public tournaments;
    mapping(uint256 => Guild) public guilds;
    mapping(address => Player) public players;
    mapping(uint256 => string) public guildNFTMetadata; // NFT metadata for guild tokens
    
    // Tournament configuration
    uint256 public platformFee = 500; // 5% platform fee
    uint256 public constant MAX_PARTICIPANTS = 1000;
    address public treasury;
    
    // Skill rating system
    uint256 public constant INITIAL_RATING = 1000;
    uint256 public constant K_FACTOR = 32; // ELO rating system K-factor

    // Events
    event TournamentCreated(
        uint256 indexed tournamentId,
        string name,
        GameType gameType,
        uint256 entryFee,
        uint256 maxParticipants
    );

    event PlayerRegistered(uint256 indexed tournamentId, address indexed player);
    event TournamentStarted(uint256 indexed tournamentId);
    event TournamentCompleted(uint256 indexed tournamentId, address indexed winner, uint256 prizeAmount);
    
    event GuildCreated(uint256 indexed guildId, string name, address indexed owner);
    event PlayerJoinedGuild(address indexed player, uint256 indexed guildId);
    event PlayerLeftGuild(address indexed player, uint256 indexed guildId);
    event GuildLevelUp(uint256 indexed guildId, uint256 newLevel);

    event GameResultRecorded(
        address indexed player1,
        address indexed player2,
        address indexed winner,
        GameType gameType,
        uint256 ratingChange
    );

    modifier onlyTournamentAdmin() {
        require(hasRole(TOURNAMENT_ADMIN_ROLE, msg.sender), "Not tournament admin");
        _;
    }

    modifier tournamentExists(uint256 tournamentId) {
        require(tournamentId > 0 && tournamentId <= tournamentCount, "Tournament does not exist");
        _;
    }

    modifier guildExists(uint256 guildId) {
        require(guildId > 0 && guildId <= guildCount, "Guild does not exist");
        _;
    }

    constructor(
        address _gameToken,
        address _treasury,
        address _monitoringSystem
    ) ERC721("Guild NFT", "GUILD") {
        require(_gameToken != address(0), "Invalid game token");
        require(_treasury != address(0), "Invalid treasury");

        gameToken = IERC20(_gameToken);
        treasury = _treasury;
        monitoringSystem = IMonitoringSystem(_monitoringSystem);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TOURNAMENT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_OPERATOR_ROLE, msg.sender);
    }

    /**
     * @dev Create a new tournament
     */
    function createTournament(
        string memory name,
        string memory description,
        GameType gameType,
        uint256 entryFee,
        uint256 maxParticipants,
        uint256 startTime,
        uint256 duration,
        bool isGuildTournament,
        uint256 requiredGuildLevel
    ) external onlyTournamentAdmin whenNotPaused returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(maxParticipants <= MAX_PARTICIPANTS, "Too many participants");
        require(startTime > block.timestamp, "Invalid start time");

        uint256 tournamentId = ++tournamentCount;
        Tournament storage tournament = tournaments[tournamentId];
        
        tournament.id = tournamentId;
        tournament.name = name;
        tournament.description = description;
        tournament.gameType = gameType;
        tournament.entryFee = entryFee;
        tournament.maxParticipants = maxParticipants;
        tournament.startTime = startTime;
        tournament.endTime = startTime + duration;
        tournament.status = TournamentStatus.Created;
        tournament.isGuildTournament = isGuildTournament;
        tournament.requiredGuildLevel = requiredGuildLevel;

        emit TournamentCreated(tournamentId, name, gameType, entryFee, maxParticipants);
        
        // Record tournament creation in monitoring system
        if (address(monitoringSystem) != address(0)) {
            monitoringSystem.recordEvent("tournament_created", tournamentId, msg.sender);
        }

        return tournamentId;
    }

    /**
     * @dev Register for a tournament
     */
    function registerForTournament(uint256 tournamentId) 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        tournamentExists(tournamentId) 
    {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == TournamentStatus.RegistrationOpen, "Registration not open");
        require(!tournament.isParticipant[msg.sender], "Already registered");
        require(tournament.participants.length < tournament.maxParticipants, "Tournament full");
        require(block.timestamp < tournament.startTime, "Registration closed");

        // Check guild requirements for guild tournaments
        if (tournament.isGuildTournament) {
            Player storage player = players[msg.sender];
            require(player.guildId > 0, "Must be in a guild");
            require(guilds[player.guildId].level >= tournament.requiredGuildLevel, "Guild level too low");
        }

        // Handle entry fee
        if (tournament.entryFee > 0) {
            require(gameToken.transferFrom(msg.sender, address(this), tournament.entryFee), "Entry fee transfer failed");
            tournament.prizePool += tournament.entryFee;
        }

        tournament.participants.push(msg.sender);
        tournament.isParticipant[msg.sender] = true;

        // Initialize player if not exists
        if (players[msg.sender].skillRating == 0) {
            players[msg.sender].playerAddress = msg.sender;
            players[msg.sender].skillRating = INITIAL_RATING;
        }

        emit PlayerRegistered(tournamentId, msg.sender);
    }

    /**
     * @dev Start tournament registration
     */
    function openRegistration(uint256 tournamentId) external onlyTournamentAdmin tournamentExists(tournamentId) {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == TournamentStatus.Created, "Invalid status");
        tournament.status = TournamentStatus.RegistrationOpen;
    }

    /**
     * @dev Start a tournament
     */
    function startTournament(uint256 tournamentId) external onlyTournamentAdmin tournamentExists(tournamentId) {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == TournamentStatus.RegistrationOpen, "Invalid status");
        require(tournament.participants.length >= 2, "Not enough participants");
        require(block.timestamp >= tournament.startTime, "Too early to start");

        tournament.status = TournamentStatus.InProgress;
        emit TournamentStarted(tournamentId);
    }

    /**
     * @dev Record game result and update ratings
     */
    function recordGameResult(
        uint256 tournamentId,
        address player1,
        address player2,
        address winner,
        uint256 player1Score,
        uint256 player2Score
    ) external onlyRole(GAME_OPERATOR_ROLE) tournamentExists(tournamentId) {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == TournamentStatus.InProgress, "Tournament not in progress");
        require(tournament.isParticipant[player1] && tournament.isParticipant[player2], "Invalid participants");

        // Update tournament scores
        tournament.playerScores[player1] += player1Score;
        tournament.playerScores[player2] += player2Score;

        // Update skill ratings using ELO system
        _updateSkillRatings(player1, player2, winner, tournament.gameType);

        emit GameResultRecorded(player1, player2, winner, tournament.gameType, 0);
    }

    /**
     * @dev Complete tournament and distribute prizes
     */
    function completeTournament(
        uint256 tournamentId,
        address winner,
        uint256[] memory finalRankings
    ) external onlyTournamentAdmin tournamentExists(tournamentId) {
        Tournament storage tournament = tournaments[tournamentId];
        require(tournament.status == TournamentStatus.InProgress, "Tournament not in progress");
        require(tournament.isParticipant[winner], "Winner not a participant");

        tournament.status = TournamentStatus.Completed;
        tournament.winner = winner;
        tournament.rankings = finalRankings;

        // Distribute prizes
        uint256 platformFeeAmount = (tournament.prizePool * platformFee) / 10000;
        uint256 winnerPrize = tournament.prizePool - platformFeeAmount;

        if (winnerPrize > 0) {
            require(gameToken.transfer(winner, winnerPrize), "Prize transfer failed");
        }

        if (platformFeeAmount > 0) {
            require(gameToken.transfer(treasury, platformFeeAmount), "Fee transfer failed");
        }

        // Update player stats
        players[winner].totalWins++;
        players[winner].tournamentPoints += 100; // Base tournament points

        // Update guild stats if guild tournament
        if (tournament.isGuildTournament) {
            uint256 winnerGuildId = players[winner].guildId;
            if (winnerGuildId > 0) {
                guilds[winnerGuildId].totalTournamentWins++;
                _addGuildExperience(winnerGuildId, 500);
            }
        }

        emit TournamentCompleted(tournamentId, winner, winnerPrize);
    }

    /**
     * @dev Create a new guild
     */
    function createGuild(
        string memory name,
        string memory description,
        string memory nftMetadata
    ) external whenNotPaused returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(players[msg.sender].guildId == 0, "Already in a guild");

        uint256 guildId = ++guildCount;
        Guild storage guild = guilds[guildId];
        
        guild.id = guildId;
        guild.name = name;
        guild.description = description;
        guild.owner = msg.sender;
        guild.level = 1;
        guild.experience = 0;
        guild.isActive = true;
        guild.memberLimit = 10; // Initial member limit
        guild.creationTime = block.timestamp;

        // Add creator as first member
        guild.members.push(msg.sender);
        guild.isMember[msg.sender] = true;
        players[msg.sender].guildId = guildId;

        // Mint NFT for guild ownership
        uint256 tokenId = nextTokenId++;
        _mint(msg.sender, tokenId);
        guildNFTMetadata[tokenId] = nftMetadata;

        emit GuildCreated(guildId, name, msg.sender);
        return guildId;
    }

    /**
     * @dev Join a guild
     */
    function joinGuild(uint256 guildId) external whenNotPaused guildExists(guildId) {
        Guild storage guild = guilds[guildId];
        require(guild.isActive, "Guild not active");
        require(players[msg.sender].guildId == 0, "Already in a guild");
        require(!guild.isMember[msg.sender], "Already a member");
        require(guild.members.length < guild.memberLimit, "Guild full");

        guild.members.push(msg.sender);
        guild.isMember[msg.sender] = true;
        players[msg.sender].guildId = guildId;

        emit PlayerJoinedGuild(msg.sender, guildId);
    }

    /**
     * @dev Leave guild
     */
    function leaveGuild() external {
        uint256 guildId = players[msg.sender].guildId;
        require(guildId > 0, "Not in a guild");
        
        Guild storage guild = guilds[guildId];
        require(guild.owner != msg.sender, "Owner cannot leave guild");

        guild.isMember[msg.sender] = false;
        players[msg.sender].guildId = 0;

        // Remove from members array
        for (uint256 i = 0; i < guild.members.length; i++) {
            if (guild.members[i] == msg.sender) {
                guild.members[i] = guild.members[guild.members.length - 1];
                guild.members.pop();
                break;
            }
        }

        emit PlayerLeftGuild(msg.sender, guildId);
    }

    /**
     * @dev Update skill ratings using ELO system
     */
    function _updateSkillRatings(address player1, address player2, address winner, GameType gameType) internal {
        Player storage p1 = players[player1];
        Player storage p2 = players[player2];

        uint256 rating1 = p1.skillRating;
        uint256 rating2 = p2.skillRating;

        // Calculate expected scores
        uint256 expected1 = _calculateExpectedScore(rating1, rating2);
        uint256 expected2 = 1000 - expected1; // Expected scores sum to 1000

        // Actual scores (1000 for winner, 0 for loser)
        uint256 actual1 = (winner == player1) ? 1000 : 0;
        uint256 actual2 = (winner == player2) ? 1000 : 0;

        // Update ratings
        int256 change1 = int256(K_FACTOR * (actual1 - expected1)) / 1000;
        int256 change2 = int256(K_FACTOR * (actual2 - expected2)) / 1000;

        p1.skillRating = uint256(int256(rating1) + change1);
        p2.skillRating = uint256(int256(rating2) + change2);

        // Update game-specific ratings
        p1.gameSpecificRatings[gameType] = p1.skillRating;
        p2.gameSpecificRatings[gameType] = p2.skillRating;

        // Update win/loss records
        if (winner == player1) {
            p1.totalWins++;
            p2.totalLosses++;
        } else {
            p2.totalWins++;
            p1.totalLosses++;
        }
    }

    /**
     * @dev Calculate expected score for ELO rating
     */
    function _calculateExpectedScore(uint256 rating1, uint256 rating2) internal pure returns (uint256) {
        int256 diff = int256(rating1) - int256(rating2);
        // Simplified ELO calculation scaled to 1000
        if (diff > 400) return 900;
        if (diff < -400) return 100;
        return uint256(int256(500) + (diff * 400) / 800);
    }

    /**
     * @dev Add experience to guild and handle level ups
     */
    function _addGuildExperience(uint256 guildId, uint256 experience) internal {
        Guild storage guild = guilds[guildId];
        guild.experience += experience;

        // Check for level up (1000 exp per level)
        uint256 newLevel = (guild.experience / 1000) + 1;
        if (newLevel > guild.level) {
            guild.level = newLevel;
            guild.memberLimit += 5; // Increase member limit
            emit GuildLevelUp(guildId, newLevel);
        }
    }

    // View functions
    function getTournamentParticipants(uint256 tournamentId) external view returns (address[] memory) {
        return tournaments[tournamentId].participants;
    }

    function getGuildMembers(uint256 guildId) external view returns (address[] memory) {
        return guilds[guildId].members;
    }

    function getPlayerStats(address player) external view returns (
        uint256 wins,
        uint256 losses,
        uint256 skillRating,
        uint256 tournamentPoints,
        uint256 guildId
    ) {
        Player storage p = players[player];
        return (p.totalWins, p.totalLosses, p.skillRating, p.tournamentPoints, p.guildId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return guildNFTMetadata[tokenId];
    }

    // Required overrides
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}