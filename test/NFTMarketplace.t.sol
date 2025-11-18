// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/NFTMarketplace.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketplace;
    GameToken public gameToken;
    GamePass public gamePass;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public seller = address(0x3);
    address public buyer1 = address(0x4);
    address public buyer2 = address(0x5);
    address public royaltyReceiver = address(0x6);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public tokenId1 = 1;
    uint256 public tokenId2 = 2;
    
    event ListingCreated(
        uint256 indexed listingId,
        address indexed seller,
        uint256 indexed tokenId,
        NFTMarketplace.ListingType listingType,
        uint256 price,
        uint256 endTime
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
    
    // Removed unused events that don't match the actual contract
    event ListingSold(
        uint256 indexed listingId,
        address indexed seller,
        address indexed buyer,
        uint256 tokenId,
        uint256 price
    );

    function setUp() public {
        // Deploy GameToken
        gameToken = new GameToken(
            "Game Token",
            "GAME",
            INITIAL_SUPPLY,
            0,
            treasury,
            admin
        );
        
        // Deploy GamePass
        gamePass = new GamePass(
            "Game Pass",
            "GPASS",
            "https://api.example.com/metadata/",
            treasury,
            admin
        );
        
        // Deploy NFTMarketplace
        marketplace = new NFTMarketplace(
            address(gameToken),
            address(gamePass),
            treasury,
            admin
        );
        
        // Enable public minting for GamePass
        vm.prank(admin);
        gamePass.setPublicMintEnabled(true);
        
        // Setup users with tokens and NFTs
        vm.prank(admin);
        gameToken.mint(buyer1, 10_000e18);
        vm.prank(admin);
        gameToken.mint(buyer2, 10_000e18);
        
        // Mint NFTs to seller
        vm.prank(admin);
        gamePass.adminMint(seller, GamePass.Tier.Bronze);
        vm.prank(admin);
        gamePass.adminMint(seller, GamePass.Tier.Silver);
        
        tokenId1 = 1;
        tokenId2 = 2;
        
        // Approve marketplace to transfer NFTs
        vm.prank(seller);
        gamePass.setApprovalForAll(address(marketplace), true);
    }

    function testInitialState() public view {
        assertEq(marketplace.nextListingId(), 1);
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.MARKETPLACE_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.PAUSER_ROLE(), admin));
    }

    function testCreateFixedPriceListing() public {
        uint256 price = 1000e18;
        
        vm.expectEmit(true, true, true, true);
        emit ListingCreated(1, seller, tokenId1, NFTMarketplace.ListingType.FixedPrice, price, 0);
        
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.seller, seller);
        assertEq(listing.tokenId, tokenId1);
        assertEq(listing.price, price);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Active));
        assertEq(listing.startTime, block.timestamp);
        
        // Check NFT is transferred to marketplace
        assertEq(gamePass.ownerOf(tokenId1), address(marketplace));
        assertEq(marketplace.nextListingId(), 2);
    }

    function testCreateFixedPriceListingNotOwner() public {
        uint256 price = 1000e18;
        
        vm.expectRevert(NFTMarketplace.NotTokenOwner.selector);
        vm.prank(buyer1);
        marketplace.createFixedPriceListing(tokenId1, price);
    }

    function testCreateFixedPriceListingZeroPrice() public {
        vm.expectRevert(NFTMarketplace.InvalidPrice.selector);
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, 0);
    }

    function testBuyFixedPriceListing() public {
        uint256 price = 1000e18;
        
        // Create listing
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        // Calculate fees
        uint256 marketplaceFee = (price * 250) / 10000; // 2.5%
        uint256 royaltyFee = (price * 500) / 10000;     // 5%
        uint256 sellerProceeds = price - marketplaceFee - royaltyFee;
        
        uint256 buyerBalanceBefore = gameToken.balanceOf(buyer1);
        uint256 sellerBalanceBefore = gameToken.balanceOf(seller);
        uint256 treasuryBalanceBefore = gameToken.balanceOf(treasury);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), price);
        
        vm.prank(buyer1);
        marketplace.buyFixedPrice(1);
        
        // Check NFT ownership
        assertEq(gamePass.ownerOf(tokenId1), buyer1);
        
        // Check balances
        assertEq(gameToken.balanceOf(buyer1), buyerBalanceBefore - price);
        assertEq(gameToken.balanceOf(seller), sellerBalanceBefore + sellerProceeds);
        assertEq(gameToken.balanceOf(treasury), treasuryBalanceBefore + marketplaceFee + royaltyFee);
        
        // Check listing is inactive
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Sold));
    }

    function testBuyInactiveListing() public {
        uint256 price = 1000e18;
        
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        // Cancel listing
        vm.prank(seller);
        marketplace.cancelListing(1);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), price);
        
        vm.expectRevert(NFTMarketplace.ListingNotActive.selector);
        vm.prank(buyer1);
        marketplace.buyFixedPrice(1);
    }

    function testCancelFixedPriceListing() public {
        uint256 price = 1000e18;
        
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        vm.prank(seller);
        marketplace.cancelListing(1);
        
        // Check NFT is returned to seller
        assertEq(gamePass.ownerOf(tokenId1), seller);
        
        // Check listing is inactive
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Cancelled));
    }

    function testCancelListingNotSeller() public {
        uint256 price = 1000e18;
        
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        vm.expectRevert(NFTMarketplace.NotListingSeller.selector);
        vm.prank(buyer1);
        marketplace.cancelListing(1);
    }

    function testCreateAuction() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        
        vm.expectEmit(true, true, true, true);
        emit ListingCreated(1, seller, tokenId1, NFTMarketplace.ListingType.Auction, startingBid, block.timestamp + duration);
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.seller, seller);
        assertEq(listing.tokenId, tokenId1);
        assertEq(listing.price, startingBid);
        assertEq(listing.currentBid, 0);
        assertEq(listing.currentBidder, address(0));
        assertEq(listing.endTime, block.timestamp + duration);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Active));
        assertEq(uint8(listing.listingType), uint8(NFTMarketplace.ListingType.Auction));
        
        // Check NFT is transferred to marketplace
        assertEq(gamePass.ownerOf(tokenId1), address(marketplace));
    }

    function testCreateAuctionInvalidDuration() public {
        uint256 startingBid = 500e18;
        uint256 invalidDuration = 30 minutes; // Too short
        
        vm.expectRevert(NFTMarketplace.InvalidDuration.selector);
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, invalidDuration);
    }

    function testPlaceBid() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 bidAmount = 600e18;
        
        // Create auction
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), bidAmount);
        
        vm.expectEmit(true, true, false, true);
        emit BidPlaced(1, buyer1, bidAmount, 1);
        
        vm.prank(buyer1);
        marketplace.placeBid(1, bidAmount);
        
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.currentBid, bidAmount);
        assertEq(listing.currentBidder, buyer1);
        assertEq(listing.bidCount, 1);
        
        // Check tokens are held in marketplace
        assertEq(gameToken.balanceOf(address(marketplace)), bidAmount);
    }

    function testPlaceBidTooLow() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 lowBid = 400e18; // Below starting bid
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), lowBid);
        
        vm.expectRevert(NFTMarketplace.BidTooLow.selector);
        vm.prank(buyer1);
        marketplace.placeBid(1, lowBid);
    }

    function testPlaceHigherBid() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 firstBid = 600e18;
        uint256 secondBid = 700e18;
        
        // Create auction
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        // First bid
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), firstBid);
        vm.prank(buyer1);
        marketplace.placeBid(1, firstBid);
        
        uint256 buyer1BalanceBefore = gameToken.balanceOf(buyer1);
        
        // Second bid (higher)
        vm.prank(buyer2);
        gameToken.approve(address(marketplace), secondBid);
        vm.prank(buyer2);
        marketplace.placeBid(1, secondBid);
        
        // Check first bidder can withdraw refund
        vm.prank(buyer1);
        marketplace.withdrawReturns();
        assertEq(gameToken.balanceOf(buyer1), buyer1BalanceBefore + firstBid);
        
        // Check auction state
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.currentBid, secondBid);
        assertEq(listing.currentBidder, buyer2);
    }

    function testBidOnExpiredAuction() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 bidAmount = 600e18;
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        // Fast forward past auction end
        vm.warp(block.timestamp + duration + 1);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), bidAmount);
        
        vm.expectRevert(NFTMarketplace.AuctionStillActive.selector);
        vm.prank(buyer1);
        marketplace.placeBid(1, bidAmount);
    }

    function testSettleAuction() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 bidAmount = 1000e18;
        
        // Create auction and place bid
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), bidAmount);
        vm.prank(buyer1);
        marketplace.placeBid(1, bidAmount);
        
        // Fast forward past auction end
        vm.warp(block.timestamp + duration + 1);
        
        // Calculate fees
        uint256 marketplaceFee = (bidAmount * 250) / 10000; // 2.5%
        uint256 royaltyFee = (bidAmount * 500) / 10000;     // 5%
        uint256 sellerProceeds = bidAmount - marketplaceFee - royaltyFee;
        
        uint256 sellerBalanceBefore = gameToken.balanceOf(seller);
        uint256 treasuryBalanceBefore = gameToken.balanceOf(treasury);
        
        vm.expectEmit(true, true, false, true);
        emit AuctionEnded(1, buyer1, bidAmount);
        
        marketplace.endAuction(1);
        
        // Check NFT ownership
        assertEq(gamePass.ownerOf(tokenId1), buyer1);
        
        // Check balances
        assertEq(gameToken.balanceOf(seller), sellerBalanceBefore + sellerProceeds);
        assertEq(gameToken.balanceOf(treasury), treasuryBalanceBefore + marketplaceFee + royaltyFee);
        
        // Check listing is sold
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Sold));
    }

    function testSettleAuctionNoBids() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        // Fast forward past auction end
        vm.warp(block.timestamp + duration + 1);
        
        marketplace.endAuction(1);
        
        // Check NFT is returned to seller
        assertEq(gamePass.ownerOf(tokenId1), seller);
        
        // Check listing is expired
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Expired));
    }

    function testCancelAuction() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        vm.prank(seller);
        marketplace.cancelListing(1);
        
        // Check NFT is returned to seller
        assertEq(gamePass.ownerOf(tokenId1), seller);
        
        // Check listing is cancelled
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Cancelled));
    }

    function testCancelAuctionWithBids() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 bidAmount = 600e18;
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), bidAmount);
        vm.prank(buyer1);
        marketplace.placeBid(1, bidAmount);
        
        vm.expectRevert(NFTMarketplace.AuctionNotEnded.selector);
        vm.prank(seller);
        marketplace.cancelListing(1);
    }

    function testBidExtension() public {
        uint256 startingBid = 500e18;
        uint256 duration = 3 days;
        uint256 bidAmount = 600e18;
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        // Place bid in last 15 minutes
        vm.warp(block.timestamp + duration - 10 * 60); // 10 minutes before end
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), bidAmount);
        vm.prank(buyer1);
        marketplace.placeBid(1, bidAmount);
        
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        // End time should be extended by 10 minutes (AUCTION_EXTENSION)
        assertEq(listing.endTime, block.timestamp + 10 * 60);
    }

    function testSetMarketplaceFee() public {
        uint16 newFee = 300; // 3%
        
        vm.prank(admin);
        marketplace.setMarketplaceFee(newFee);
        
        // Note: Contract doesn't have a getter, so we can't directly test the value
        // This test just ensures the function can be called without reverting
    }

    function testSetRoyaltyFee() public {
        uint16 newFee = 750; // 7.5%
        
        vm.prank(admin);
        marketplace.setRoyaltyFee(newFee);
        
        // Note: Contract doesn't have a getter, so we can't directly test the value
        // This test just ensures the function can be called without reverting
    }

    function testSetTreasury() public {
        address newTreasury = address(0x7);
        
        vm.prank(admin);
        marketplace.setTreasury(newTreasury);
        
        // Note: Contract doesn't have a getter, so we can't directly test the value
        // This test just ensures the function can be called without reverting
    }

    function testPauseAndUnpause() public {
        vm.prank(admin);
        marketplace.pause();
        assertTrue(marketplace.paused());
        
        uint256 price = 1000e18;
        
        vm.expectRevert("Pausable: paused");
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        vm.prank(admin);
        marketplace.unpause();
        assertFalse(marketplace.paused());
        
        // Should work now
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
    }

    // Note: getActiveListings and getActiveAuctions functions don't exist in the actual contract
    // These tests are removed to match the actual contract implementation

    function testAccessControl() public {
        // Non-admin cannot set fees
        vm.expectRevert();
        vm.prank(buyer1);
        marketplace.setMarketplaceFee(300);
        
        // Non-admin cannot set treasury
        vm.expectRevert();
        vm.prank(buyer1);
        marketplace.setTreasury(address(0x7));
        
        // Non-pauser cannot pause
        vm.expectRevert();
        vm.prank(buyer1);
        marketplace.pause();
    }

    // Fuzz tests
    function testFuzzFixedPriceListing(uint256 price) public {
        vm.assume(price > 0 && price <= 100_000e18);
        
        vm.prank(seller);
        marketplace.createFixedPriceListing(tokenId1, price);
        
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.price, price);
        assertEq(uint8(listing.status), uint8(NFTMarketplace.ListingStatus.Active));
    }

    function testFuzzAuctionBid(uint256 startingBid, uint256 bidAmount) public {
        vm.assume(startingBid > 0 && startingBid <= 10_000e18);
        vm.assume(bidAmount >= startingBid && bidAmount <= 50_000e18);
        
        uint256 duration = 3 days;
        
        vm.prank(seller);
        marketplace.createAuction(tokenId1, startingBid, duration);
        
        vm.prank(admin);
        gameToken.mint(buyer1, bidAmount);
        
        vm.prank(buyer1);
        gameToken.approve(address(marketplace), bidAmount);
        vm.prank(buyer1);
        marketplace.placeBid(1, bidAmount);
        
        NFTMarketplace.Listing memory listing = marketplace.getListing(1);
        assertEq(listing.currentBid, bidAmount);
        assertEq(listing.currentBidder, buyer1);
    }
}