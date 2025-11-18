// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GamePass.sol";

/**
 * @title NFTMarketplace
 * @notice Marketplace for trading GamePass NFTs using GAME tokens
 * @dev Supports direct sales and time-based auctions with fees
 */
contract NFTMarketplace is IERC721Receiver, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role for marketplace administration
    bytes32 public constant MARKETPLACE_ADMIN_ROLE = keccak256("MARKETPLACE_ADMIN_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Game token for payments
    IERC20 public immutable gameToken;

    /// @notice GamePass NFT contract
    GamePass public immutable gamePass;

    /// @notice Treasury for fee collection
    address public treasury;

    /// @notice Marketplace fee in basis points
    uint16 public marketplaceFee;

    /// @notice Royalty fee for original creators in basis points
    uint16 public royaltyFee;

    /// @notice Minimum auction duration
    uint256 public constant MIN_AUCTION_DURATION = 1 hours;

    /// @notice Maximum auction duration
    uint256 public constant MAX_AUCTION_DURATION = 30 days;

    /// @notice Auction extension time when bid placed near end
    uint256 public constant AUCTION_EXTENSION = 10 minutes;

    /// @notice Listing types
    enum ListingType {
        FixedPrice,
        Auction
    }

    /// @notice Listing status
    enum ListingStatus {
        Active,
        Sold,
        Cancelled,
        Expired
    }

    /// @notice Marketplace listing
    struct Listing {
        uint256 listingId;
        address seller;
        uint256 tokenId;
        ListingType listingType;
        ListingStatus status;
        uint256 price;          // For fixed price or starting bid
        uint256 currentBid;     // Current highest bid (auctions)
        address currentBidder;  // Current highest bidder
        uint256 startTime;
        uint256 endTime;        // For auctions
        uint256 bidCount;
    }

    /// @notice Bid information
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    /// @notice Next listing ID
    uint256 public nextListingId;

    /// @notice Mapping from listing ID to listing
    mapping(uint256 => Listing) public listings;

    /// @notice Mapping from listing ID to all bids
    mapping(uint256 => Bid[]) public listingBids;

    /// @notice Mapping from user to their listings
    mapping(address => uint256[]) public userListings;

    /// @notice Mapping from user to their bids
    mapping(address => uint256[]) public userBids;

    /// @notice Mapping to track if user has active bid on listing
    mapping(uint256 => mapping(address => bool)) public hasActiveBid;

    /// @notice Mapping for bid amounts to refund
    mapping(address => uint256) public pendingReturns;

    /// @notice Events
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed tokenId,
        ListingType listingType,
        uint256 price,
        uint256 endTime
    );
    
    event ListingSold(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        uint256 tokenId,
        uint256 price
    );
    
    event BidPlaced(
        uint256 indexed listingId,
        address indexed bidder,
        uint256 amount,
        uint256 bidCount
    );
    
    event AuctionEnded(
        uint256 indexed listingId,
        address indexed winner,
        uint256 winningBid
    );
    
    event ListingCancelled(uint256 indexed listingId);
    event AuctionExtended(uint256 indexed listingId, uint256 newEndTime);
    event MarketplaceFeeUpdated(uint16 newFee);
    event RoyaltyFeeUpdated(uint16 newFee);

    /// @notice Custom errors
    error InvalidTokenId();
    error NotTokenOwner();
    error TokenNotApproved();
    error InvalidPrice();
    error InvalidDuration();
    error ListingNotFound();
    error ListingNotActive();
    error ListingExpired();
    error AuctionNotEnded();
    error AuctionStillActive();
    error BidTooLow();
    error CannotBidOnOwnListing();
    error NotListingSeller();
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAddress();

    /**
     * @notice Constructor
     * @param gameTokenAddress Game token address
     * @param gamePassAddress GamePass NFT address
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

        // Set default fees
        marketplaceFee = 250; // 2.5%
        royaltyFee = 500;     // 5% to original creator (platform)

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MARKETPLACE_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Start listing IDs at 1
        nextListingId = 1;
    }

    /**
     * @notice Create a fixed price listing
     * @param tokenId Token ID to sell
     * @param price Sale price in GAME tokens
     */
    function createFixedPriceListing(uint256 tokenId, uint256 price) 
        external 
        whenNotPaused 
        nonReentrant 
    {
        if (price == 0) revert InvalidPrice();
        if (gamePass.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (!gamePass.isApprovedForAll(msg.sender, address(this)) && 
            gamePass.getApproved(tokenId) != address(this)) {
            revert TokenNotApproved();
        }

        uint256 listingId = nextListingId++;

        listings[listingId] = Listing({
            listingId: listingId,
            seller: msg.sender,
            tokenId: tokenId,
            listingType: ListingType.FixedPrice,
            status: ListingStatus.Active,
            price: price,
            currentBid: 0,
            currentBidder: address(0),
            startTime: block.timestamp,
            endTime: 0,
            bidCount: 0
        });

        userListings[msg.sender].push(listingId);

        // Transfer NFT to marketplace for escrow
        gamePass.safeTransferFrom(msg.sender, address(this), tokenId);

        emit ListingCreated(listingId, msg.sender, tokenId, ListingType.FixedPrice, price, 0);
    }

    /**
     * @notice Create an auction listing
     * @param tokenId Token ID to auction
     * @param startingBid Starting bid amount
     * @param duration Auction duration in seconds
     */
    function createAuction(uint256 tokenId, uint256 startingBid, uint256 duration)
        external
        whenNotPaused
        nonReentrant
    {
        if (startingBid == 0) revert InvalidPrice();
        if (duration < MIN_AUCTION_DURATION || duration > MAX_AUCTION_DURATION) {
            revert InvalidDuration();
        }
        if (gamePass.ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (!gamePass.isApprovedForAll(msg.sender, address(this)) && 
            gamePass.getApproved(tokenId) != address(this)) {
            revert TokenNotApproved();
        }

        uint256 listingId = nextListingId++;
        uint256 endTime = block.timestamp + duration;

        listings[listingId] = Listing({
            listingId: listingId,
            seller: msg.sender,
            tokenId: tokenId,
            listingType: ListingType.Auction,
            status: ListingStatus.Active,
            price: startingBid,
            currentBid: 0,
            currentBidder: address(0),
            startTime: block.timestamp,
            endTime: endTime,
            bidCount: 0
        });

        userListings[msg.sender].push(listingId);

        // Transfer NFT to marketplace for escrow
        gamePass.safeTransferFrom(msg.sender, address(this), tokenId);

        emit ListingCreated(listingId, msg.sender, tokenId, ListingType.Auction, startingBid, endTime);
    }

    /**
     * @notice Buy NFT at fixed price
     * @param listingId Listing ID
     */
    function buyFixedPrice(uint256 listingId) external whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        
        if (listing.seller == address(0)) revert ListingNotFound();
        if (listing.status != ListingStatus.Active) revert ListingNotActive();
        if (listing.listingType != ListingType.FixedPrice) revert ListingNotFound();
        if (listing.seller == msg.sender) revert CannotBidOnOwnListing();

        listing.status = ListingStatus.Sold;

        _executeSale(listingId, msg.sender, listing.price);

        emit ListingSold(listingId, listing.seller, msg.sender, listing.tokenId, listing.price);
    }

    /**
     * @notice Place bid on auction
     * @param listingId Listing ID
     * @param bidAmount Bid amount
     */
    function placeBid(uint256 listingId, uint256 bidAmount) external whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        
        if (listing.seller == address(0)) revert ListingNotFound();
        if (listing.status != ListingStatus.Active) revert ListingNotActive();
        if (listing.listingType != ListingType.Auction) revert ListingNotFound();
        if (block.timestamp >= listing.endTime) revert AuctionStillActive();
        if (listing.seller == msg.sender) revert CannotBidOnOwnListing();

        uint256 minBid = listing.currentBid > 0 ? 
            listing.currentBid + (listing.currentBid * 500 / 10000) : // 5% increase
            listing.price; // Starting bid

        if (bidAmount < minBid) revert BidTooLow();

        // Transfer bid amount to contract
        gameToken.safeTransferFrom(msg.sender, address(this), bidAmount);

        // Refund previous bidder
        if (listing.currentBidder != address(0)) {
            pendingReturns[listing.currentBidder] += listing.currentBid;
            hasActiveBid[listingId][listing.currentBidder] = false;
        }

        // Update listing
        listing.currentBid = bidAmount;
        listing.currentBidder = msg.sender;
        listing.bidCount++;

        // Record bid
        listingBids[listingId].push(Bid({
            bidder: msg.sender,
            amount: bidAmount,
            timestamp: block.timestamp
        }));

        hasActiveBid[listingId][msg.sender] = true;
        userBids[msg.sender].push(listingId);

        // Extend auction if bid placed near end
        if (listing.endTime - block.timestamp < AUCTION_EXTENSION) {
            listing.endTime = block.timestamp + AUCTION_EXTENSION;
            emit AuctionExtended(listingId, listing.endTime);
        }

        emit BidPlaced(listingId, msg.sender, bidAmount, listing.bidCount);
    }

    /**
     * @notice End auction and transfer NFT to winner
     * @param listingId Listing ID
     */
    function endAuction(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        if (listing.seller == address(0)) revert ListingNotFound();
        if (listing.listingType != ListingType.Auction) revert ListingNotFound();
        if (listing.status != ListingStatus.Active) revert ListingNotActive();
        if (block.timestamp < listing.endTime) revert AuctionNotEnded();

        listing.status = ListingStatus.Sold;

        if (listing.currentBidder != address(0)) {
            // Execute sale to highest bidder
            _executeSale(listingId, listing.currentBidder, listing.currentBid);
            hasActiveBid[listingId][listing.currentBidder] = false;
            
            emit AuctionEnded(listingId, listing.currentBidder, listing.currentBid);
            emit ListingSold(listingId, listing.seller, listing.currentBidder, listing.tokenId, listing.currentBid);
        } else {
            // No bids - return NFT to seller
            listing.status = ListingStatus.Expired;
            gamePass.safeTransferFrom(address(this), listing.seller, listing.tokenId);
            emit AuctionEnded(listingId, address(0), 0);
        }
    }

    /**
     * @notice Cancel active listing
     * @param listingId Listing ID
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        if (listing.seller == address(0)) revert ListingNotFound();
        if (listing.seller != msg.sender) revert NotListingSeller();
        if (listing.status != ListingStatus.Active) revert ListingNotActive();

        // For auctions, check if there are bids
        if (listing.listingType == ListingType.Auction && listing.currentBidder != address(0)) {
            revert AuctionNotEnded(); // Cannot cancel auction with bids
        }

        listing.status = ListingStatus.Cancelled;

        // Return NFT to seller
        gamePass.safeTransferFrom(address(this), listing.seller, listing.tokenId);

        emit ListingCancelled(listingId);
    }

    /**
     * @notice Withdraw pending returns
     */
    function withdrawReturns() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            gameToken.safeTransfer(msg.sender, amount);
        }
    }

    /**
     * @notice Set marketplace fee
     * @param newFee New fee in basis points (0-10000)
     */
    function setMarketplaceFee(uint16 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 10000, "Fee cannot exceed 100%");
        marketplaceFee = newFee;
        emit MarketplaceFeeUpdated(newFee);
    }

    /**
     * @notice Set royalty fee
     * @param newFee New fee in basis points (0-10000)
     */
    function setRoyaltyFee(uint16 newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newFee <= 10000, "Fee cannot exceed 100%");
        royaltyFee = newFee;
        emit RoyaltyFeeUpdated(newFee);
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
     * @notice Get listing details
     * @param listingId Listing ID
     * @return Listing details
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @notice Get all bids for a listing
     * @param listingId Listing ID
     * @return Array of bids
     */
    function getListingBids(uint256 listingId) external view returns (Bid[] memory) {
        return listingBids[listingId];
    }

    /**
     * @notice Get user's listings
     * @param user User address
     * @return Array of listing IDs
     */
    function getUserListings(address user) external view returns (uint256[] memory) {
        return userListings[user];
    }

    /**
     * @notice Get user's bids
     * @param user User address
     * @return Array of listing IDs they've bid on
     */
    function getUserBids(address user) external view returns (uint256[] memory) {
        return userBids[user];
    }

    /**
     * @notice Get active listings count
     * @return Number of active listings
     */
    function getActiveListingsCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 1; i < nextListingId; i++) {
            if (listings[i].status == ListingStatus.Active) {
                count++;
            }
        }
        return count;
    }

    /**
     * @notice Execute sale and distribute payments
     * @param listingId Listing ID
     * @param buyer Buyer address
     * @param price Sale price
     */
    function _executeSale(uint256 listingId, address buyer, uint256 price) internal {
        Listing storage listing = listings[listingId];
        
        // Calculate fees
        uint256 marketplaceFeeAmount = (price * marketplaceFee) / 10000;
        uint256 royaltyFeeAmount = (price * royaltyFee) / 10000;
        uint256 sellerAmount = price - marketplaceFeeAmount - royaltyFeeAmount;

        // Transfer payments
        if (sellerAmount > 0) {
            gameToken.safeTransfer(listing.seller, sellerAmount);
        }
        
        if (marketplaceFeeAmount > 0) {
            gameToken.safeTransfer(treasury, marketplaceFeeAmount);
        }
        
        if (royaltyFeeAmount > 0) {
            gameToken.safeTransfer(treasury, royaltyFeeAmount); // Platform gets royalty
        }

        // Transfer NFT to buyer
        gamePass.safeTransferFrom(address(this), buyer, listing.tokenId);
    }

    /**
     * @notice Handle NFT transfers to this contract
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}