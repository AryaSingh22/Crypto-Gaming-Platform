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
 * @title SocialGameFi
 * @dev Social features contract with Web3 identity, community pools, and social interactions
 */
contract SocialGameFi is ERC721, ERC721Enumerable, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant SOCIAL_ADMIN_ROLE = keccak256("SOCIAL_ADMIN_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant CONTENT_MODERATOR_ROLE = keccak256("CONTENT_MODERATOR_ROLE");

    enum ProfileStatus {
        Active,
        Suspended,
        Banned,
        Verified
    }

    enum CommunityPoolType {
        Gaming,
        Investment,
        Charity,
        Tournament,
        Social
    }

    enum MessageType {
        Text,
        Image,
        GameInvite,
        PoolInvite,
        Achievement
    }

    struct Web3Profile {
        address owner;
        string username;
        string displayName;
        string bio;
        string avatarURI;
        uint256 reputation;
        uint256 socialScore;
        ProfileStatus status;
        uint256 createdAt;
        uint256 lastActiveAt;
        bool isVerified;
        string[] socialLinks;
        mapping(address => bool) isFollowing;
        mapping(address => bool) isFollower;
        uint256 followerCount;
        uint256 followingCount;
        uint256[] achievements;
        mapping(string => string) customFields;
    }

    struct CommunityPool {
        uint256 id;
        string name;
        string description;
        CommunityPoolType poolType;
        address creator;
        address[] members;
        mapping(address => bool) isMember;
        mapping(address => uint256) contributions;
        uint256 totalContributions;
        uint256 targetAmount;
        uint256 createdAt;
        uint256 endTime;
        bool isActive;
        bool isPublic;
        uint256 maxMembers;
        uint256 minContribution;
        address beneficiary;
        mapping(address => bool) hasVoted;
        mapping(bytes32 => uint256) proposalVotes;
    }

    struct SocialMessage {
        uint256 id;
        address sender;
        address recipient;
        uint256 poolId; // 0 if not pool message
        MessageType messageType;
        string content;
        string metadata; // JSON metadata for rich content
        uint256 timestamp;
        bool isEdited;
        bool isDeleted;
        uint256 likes;
        uint256 replies;
        mapping(address => bool) hasLiked;
        mapping(address => bool) hasReported;
        uint256 reportCount;
    }

    struct Achievement {
        uint256 id;
        string name;
        string description;
        string iconURI;
        uint256 points;
        bool isActive;
        mapping(address => bool) hasEarned;
        mapping(address => uint256) earnedTimestamp;
        uint256 totalEarned;
        bytes32[] requirements; // Encoded requirements
    }

    struct SocialInteraction {
        address user1;
        address user2;
        string interactionType; // "like", "follow", "message", "pool_join"
        uint256 timestamp;
        bytes data; // Additional interaction data
    }

    // State variables
    IERC20 public gameToken;
    IMonitoringSystem public monitoringSystem;
    
    mapping(address => Web3Profile) public profiles;
    mapping(string => address) public usernameToAddress;
    mapping(uint256 => CommunityPool) public communityPools;
    mapping(uint256 => SocialMessage) public messages;
    mapping(uint256 => Achievement) public achievements;
    
    uint256 public nextTokenId = 1; // For profile NFTs
    uint256 public poolCount;
    uint256 public messageCount;
    uint256 public achievementCount;
    
    address[] public allUsers;
    uint256[] public activePoolIds;
    
    // Social graph tracking
    mapping(address => SocialInteraction[]) public userInteractions;
    mapping(address => uint256) public socialScores;
    
    // Reputation system
    uint256 public constant BASE_REPUTATION = 100;
    uint256 public constant MAX_REPUTATION = 10000;
    uint256 public constant REPUTATION_DECAY_RATE = 1; // Per day
    
    // Community pool settings
    uint256 public poolCreationFee = 10 * 10**18; // 10 tokens
    uint256 public platformFeePercentage = 250; // 2.5%
    address public treasury;

    // Events
    event ProfileCreated(address indexed user, string username, uint256 tokenId);
    event ProfileUpdated(address indexed user, string field);
    event UserFollowed(address indexed follower, address indexed followed);
    event UserUnfollowed(address indexed follower, address indexed unfollowed);
    event CommunityPoolCreated(uint256 indexed poolId, address indexed creator, string name);
    event PoolContribution(uint256 indexed poolId, address indexed contributor, uint256 amount);
    event MessageSent(uint256 indexed messageId, address indexed sender, address indexed recipient);
    event MessageLiked(uint256 indexed messageId, address indexed liker);
    event AchievementEarned(address indexed user, uint256 indexed achievementId);
    event ReputationUpdated(address indexed user, uint256 oldReputation, uint256 newReputation);
    event SocialInteractionRecorded(address indexed user1, address indexed user2, string interactionType);

    modifier onlyProfileOwner(address user) {
        require(profiles[msg.sender].owner == msg.sender, "Not profile owner");
        _;
    }

    modifier profileExists(address user) {
        require(profiles[user].owner != address(0), "Profile does not exist");
        _;
    }

    modifier poolExists(uint256 poolId) {
        require(poolId > 0 && poolId <= poolCount, "Pool does not exist");
        _;
    }

    constructor(
        address _gameToken,
        address _treasury,
        address _monitoringSystem
    ) ERC721("GameFi Social Profile", "GSP") {
        require(_gameToken != address(0), "Invalid game token");
        require(_treasury != address(0), "Invalid treasury");
        
        gameToken = IERC20(_gameToken);
        treasury = _treasury;
        monitoringSystem = IMonitoringSystem(_monitoringSystem);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SOCIAL_ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, msg.sender);
        _grantRole(CONTENT_MODERATOR_ROLE, msg.sender);
        
        _initializeAchievements();
    }

    /**
     * @dev Create Web3 profile and mint profile NFT
     */
    function createProfile(
        string memory username,
        string memory displayName,
        string memory bio,
        string memory avatarURI
    ) external whenNotPaused returns (uint256) {
        require(profiles[msg.sender].owner == address(0), "Profile already exists");
        require(bytes(username).length >= 3 && bytes(username).length <= 20, "Invalid username length");
        require(usernameToAddress[username] == address(0), "Username taken");
        
        // Mint profile NFT
        uint256 tokenId = nextTokenId++;
        _mint(msg.sender, tokenId);
        
        // Create profile
        Web3Profile storage profile = profiles[msg.sender];
        profile.owner = msg.sender;
        profile.username = username;
        profile.displayName = displayName;
        profile.bio = bio;
        profile.avatarURI = avatarURI;
        profile.reputation = BASE_REPUTATION;
        profile.socialScore = 0;
        profile.status = ProfileStatus.Active;
        profile.createdAt = block.timestamp;
        profile.lastActiveAt = block.timestamp;
        profile.isVerified = false;
        
        usernameToAddress[username] = msg.sender;
        allUsers.push(msg.sender);
        
        emit ProfileCreated(msg.sender, username, tokenId);
        
        // Award profile creation achievement
        _awardAchievement(msg.sender, 1); // Profile Creator achievement
        
        return tokenId;
    }

    /**
     * @dev Update profile information
     */
    function updateProfile(
        string memory displayName,
        string memory bio,
        string memory avatarURI,
        string[] memory socialLinks
    ) external onlyProfileOwner(msg.sender) {
        Web3Profile storage profile = profiles[msg.sender];
        
        profile.displayName = displayName;
        profile.bio = bio;
        profile.avatarURI = avatarURI;
        profile.socialLinks = socialLinks;
        profile.lastActiveAt = block.timestamp;
        
        emit ProfileUpdated(msg.sender, "profile_info");
    }

    /**
     * @dev Follow another user
     */
    function followUser(address userToFollow) external profileExists(userToFollow) {
        require(userToFollow != msg.sender, "Cannot follow yourself");
        require(!profiles[msg.sender].isFollowing[userToFollow], "Already following");
        
        profiles[msg.sender].isFollowing[userToFollow] = true;
        profiles[msg.sender].followingCount++;
        
        profiles[userToFollow].isFollower[msg.sender] = true;
        profiles[userToFollow].followerCount++;
        
        // Update social scores
        _updateSocialScore(msg.sender, 5);
        _updateSocialScore(userToFollow, 10);
        
        // Record interaction
        _recordSocialInteraction(msg.sender, userToFollow, "follow");
        
        emit UserFollowed(msg.sender, userToFollow);
    }

    /**
     * @dev Unfollow a user
     */
    function unfollowUser(address userToUnfollow) external {
        require(profiles[msg.sender].isFollowing[userToUnfollow], "Not following");
        
        profiles[msg.sender].isFollowing[userToUnfollow] = false;
        profiles[msg.sender].followingCount--;
        
        profiles[userToUnfollow].isFollower[msg.sender] = false;
        profiles[userToUnfollow].followerCount--;
        
        // Record interaction
        _recordSocialInteraction(msg.sender, userToUnfollow, "unfollow");
        
        emit UserUnfollowed(msg.sender, userToUnfollow);
    }

    /**
     * @dev Create a community pool
     */
    function createCommunityPool(
        string memory name,
        string memory description,
        CommunityPoolType poolType,
        uint256 targetAmount,
        uint256 duration,
        bool isPublic,
        uint256 maxMembers,
        uint256 minContribution
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(profiles[msg.sender].owner != address(0), "Profile required");
        require(msg.value >= poolCreationFee || gameToken.transferFrom(msg.sender, treasury, poolCreationFee), "Pool creation fee required");
        require(bytes(name).length > 0, "Name required");
        require(targetAmount > 0, "Target amount required");
        require(duration > 0, "Duration required");
        
        uint256 poolId = ++poolCount;
        CommunityPool storage pool = communityPools[poolId];
        
        pool.id = poolId;
        pool.name = name;
        pool.description = description;
        pool.poolType = poolType;
        pool.creator = msg.sender;
        pool.targetAmount = targetAmount;
        pool.createdAt = block.timestamp;
        pool.endTime = block.timestamp + duration;
        pool.isActive = true;
        pool.isPublic = isPublic;
        pool.maxMembers = maxMembers;
        pool.minContribution = minContribution;
        pool.beneficiary = msg.sender; // Default to creator
        
        // Add creator as first member
        pool.members.push(msg.sender);
        pool.isMember[msg.sender] = true;
        
        activePoolIds.push(poolId);
        
        emit CommunityPoolCreated(poolId, msg.sender, name);
        
        // Award pool creation achievement
        _awardAchievement(msg.sender, 2); // Pool Creator achievement
        
        return poolId;
    }

    /**
     * @dev Contribute to a community pool
     */
    function contributeToPool(
        uint256 poolId,
        uint256 amount
    ) external nonReentrant whenNotPaused poolExists(poolId) {
        CommunityPool storage pool = communityPools[poolId];
        require(pool.isActive, "Pool not active");
        require(block.timestamp < pool.endTime, "Pool ended");
        require(amount >= pool.minContribution, "Below minimum contribution");
        require(pool.members.length < pool.maxMembers, "Pool full");
        
        require(gameToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Add member if not already a member
        if (!pool.isMember[msg.sender]) {
            pool.members.push(msg.sender);
            pool.isMember[msg.sender] = true;
        }
        
        pool.contributions[msg.sender] += amount;
        pool.totalContributions += amount;
        
        // Update reputation
        _updateReputation(msg.sender, 20);
        
        emit PoolContribution(poolId, msg.sender, amount);
        
        // Check if target reached
        if (pool.totalContributions >= pool.targetAmount) {
            _finalizePool(poolId);
        }
    }

    /**
     * @dev Send a message
     */
    function sendMessage(
        address recipient,
        uint256 poolId,
        MessageType messageType,
        string memory content,
        string memory metadata
    ) external whenNotPaused returns (uint256) {
        require(profiles[msg.sender].owner != address(0), "Profile required");
        require(bytes(content).length > 0, "Content required");
        
        if (recipient != address(0)) {
            require(profiles[recipient].owner != address(0), "Recipient profile required");
        }
        
        if (poolId > 0) {
            require(communityPools[poolId].isMember[msg.sender], "Not pool member");
        }
        
        uint256 messageId = ++messageCount;
        SocialMessage storage message = messages[messageId];
        
        message.id = messageId;
        message.sender = msg.sender;
        message.recipient = recipient;
        message.poolId = poolId;
        message.messageType = messageType;
        message.content = content;
        message.metadata = metadata;
        message.timestamp = block.timestamp;
        
        // Update last active time
        profiles[msg.sender].lastActiveAt = block.timestamp;
        
        // Record interaction
        if (recipient != address(0)) {
            _recordSocialInteraction(msg.sender, recipient, "message");
        }
        
        emit MessageSent(messageId, msg.sender, recipient);
        
        return messageId;
    }

    /**
     * @dev Like a message
     */
    function likeMessage(uint256 messageId) external {
        require(messageId <= messageCount, "Message does not exist");
        require(!messages[messageId].hasLiked[msg.sender], "Already liked");
        
        messages[messageId].hasLiked[msg.sender] = true;
        messages[messageId].likes++;
        
        // Update social scores
        _updateSocialScore(msg.sender, 1);
        _updateSocialScore(messages[messageId].sender, 2);
        
        emit MessageLiked(messageId, msg.sender);
    }

    /**
     * @dev Initialize default achievements
     */
    function _initializeAchievements() internal {
        _createAchievement("Profile Creator", "Created your first Web3 profile", "", 100);
        _createAchievement("Pool Creator", "Created your first community pool", "", 200);
        _createAchievement("Social Butterfly", "Followed 10 users", "", 150);
        _createAchievement("Community Builder", "Contributed to 5 pools", "", 300);
        _createAchievement("Influencer", "Gained 100 followers", "", 500);
    }

    /**
     * @dev Create a new achievement
     */
    function _createAchievement(
        string memory name,
        string memory description,
        string memory iconURI,
        uint256 points
    ) internal returns (uint256) {
        uint256 achievementId = ++achievementCount;
        Achievement storage achievement = achievements[achievementId];
        
        achievement.id = achievementId;
        achievement.name = name;
        achievement.description = description;
        achievement.iconURI = iconURI;
        achievement.points = points;
        achievement.isActive = true;
        
        return achievementId;
    }

    /**
     * @dev Award achievement to user
     */
    function _awardAchievement(address user, uint256 achievementId) internal {
        require(achievementId <= achievementCount, "Achievement does not exist");
        require(!achievements[achievementId].hasEarned[user], "Already earned");
        
        achievements[achievementId].hasEarned[user] = true;
        achievements[achievementId].earnedTimestamp[user] = block.timestamp;
        achievements[achievementId].totalEarned++;
        
        profiles[user].achievements.push(achievementId);
        
        // Update reputation
        _updateReputation(user, achievements[achievementId].points);
        
        emit AchievementEarned(user, achievementId);
    }

    /**
     * @dev Update user's reputation
     */
    function _updateReputation(address user, uint256 points) internal {
        uint256 oldReputation = profiles[user].reputation;
        uint256 newReputation = oldReputation + points;
        
        if (newReputation > MAX_REPUTATION) {
            newReputation = MAX_REPUTATION;
        }
        
        profiles[user].reputation = newReputation;
        
        emit ReputationUpdated(user, oldReputation, newReputation);
    }

    /**
     * @dev Update user's social score
     */
    function _updateSocialScore(address user, uint256 points) internal {
        profiles[user].socialScore += points;
    }

    /**
     * @dev Record social interaction
     */
    function _recordSocialInteraction(
        address user1,
        address user2,
        string memory interactionType
    ) internal {
        SocialInteraction memory interaction = SocialInteraction({
            user1: user1,
            user2: user2,
            interactionType: interactionType,
            timestamp: block.timestamp,
            data: ""
        });
        
        userInteractions[user1].push(interaction);
        userInteractions[user2].push(interaction);
        
        emit SocialInteractionRecorded(user1, user2, interactionType);
    }

    /**
     * @dev Finalize community pool
     */
    function _finalizePool(uint256 poolId) internal {
        CommunityPool storage pool = communityPools[poolId];
        pool.isActive = false;
        
        // Transfer funds to beneficiary (minus platform fee)
        uint256 platformFee = (pool.totalContributions * platformFeePercentage) / 10000;
        uint256 beneficiaryAmount = pool.totalContributions - platformFee;
        
        require(gameToken.transfer(pool.beneficiary, beneficiaryAmount), "Beneficiary transfer failed");
        require(gameToken.transfer(treasury, platformFee), "Platform fee transfer failed");
        
        // Award achievements to contributors
        for (uint256 i = 0; i < pool.members.length; i++) {
            if (pool.contributions[pool.members[i]] > 0) {
                _updateReputation(pool.members[i], 50);
            }
        }
    }

    // View functions
    function getProfile(address user) external view returns (
        string memory username,
        string memory displayName,
        string memory bio,
        uint256 reputation,
        uint256 socialScore,
        ProfileStatus status,
        bool isVerified,
        uint256 followerCount,
        uint256 followingCount
    ) {
        Web3Profile storage profile = profiles[user];
        return (
            profile.username,
            profile.displayName,
            profile.bio,
            profile.reputation,
            profile.socialScore,
            profile.status,
            profile.isVerified,
            profile.followerCount,
            profile.followingCount
        );
    }

    function getCommunityPool(uint256 poolId) external view returns (
        string memory name,
        string memory description,
        CommunityPoolType poolType,
        address creator,
        uint256 totalContributions,
        uint256 targetAmount,
        uint256 endTime,
        bool isActive,
        uint256 memberCount
    ) {
        CommunityPool storage pool = communityPools[poolId];
        return (
            pool.name,
            pool.description,
            pool.poolType,
            pool.creator,
            pool.totalContributions,
            pool.targetAmount,
            pool.endTime,
            pool.isActive,
            pool.members.length
        );
    }

    function getMessage(uint256 messageId) external view returns (
        address sender,
        address recipient,
        uint256 poolId,
        MessageType messageType,
        string memory content,
        uint256 timestamp,
        uint256 likes,
        bool isDeleted
    ) {
        SocialMessage storage message = messages[messageId];
        return (
            message.sender,
            message.recipient,
            message.poolId,
            message.messageType,
            message.content,
            message.timestamp,
            message.likes,
            message.isDeleted
        );
    }

    function getUserAchievements(address user) external view returns (uint256[] memory) {
        return profiles[user].achievements;
    }

    function getPoolMembers(uint256 poolId) external view returns (address[] memory) {
        return communityPools[poolId].members;
    }

    function isFollowing(address follower, address followed) external view returns (bool) {
        return profiles[follower].isFollowing[followed];
    }

    function getActivePoolIds() external view returns (uint256[] memory) {
        return activePoolIds;
    }

    // Admin functions
    function verifyProfile(address user) external onlyRole(MODERATOR_ROLE) {
        profiles[user].isVerified = true;
        profiles[user].status = ProfileStatus.Verified;
        emit ProfileUpdated(user, "verification");
    }

    function moderateMessage(uint256 messageId, bool delete_) external onlyRole(CONTENT_MODERATOR_ROLE) {
        messages[messageId].isDeleted = delete_;
    }

    function updatePoolCreationFee(uint256 newFee) external onlyRole(SOCIAL_ADMIN_ROLE) {
        poolCreationFee = newFee;
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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        address owner = ownerOf(tokenId);
        return profiles[owner].avatarURI;
    }
}