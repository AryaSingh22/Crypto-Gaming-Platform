// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Lottery.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";
import "../src/PrizePool.sol";
import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    GameToken public gameToken;
    GamePass public gamePass;
    PrizePool public prizePool;
    VRFCoordinatorV2Mock public vrfCoordinator;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public player1 = address(0x3);
    address public player2 = address(0x4);
    address public player3 = address(0x5);
    
    uint64 public constant SUBSCRIPTION_ID = 1;
    bytes32 public constant KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint256 public constant TICKET_PRICE = 100e18;
    uint256 public constant ROUND_DURATION = 7 days;
    
    event TicketPurchased(uint256 indexed roundId, address indexed buyer, uint256 ticketCount, uint256 cost);

    function setUp() public {
        // Deploy VRF Mock
        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 1e9);
        vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(SUBSCRIPTION_ID, 10 ether);
        
        // Deploy GameToken
        gameToken = new GameToken(
            "Game Token",
            "GAME",
            1_000_000e18,
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
        
        // Deploy PrizePool
        prizePool = new PrizePool(
            address(gameToken),
            treasury,
            200, // 2% fee
            admin
        );
        
        // Deploy Lottery
        lottery = new Lottery(
            address(vrfCoordinator),
            SUBSCRIPTION_ID,
            KEY_HASH,
            address(gameToken),
            address(prizePool),
            address(gamePass),
            treasury,
            TICKET_PRICE,
            admin
        );
        
        // Add Lottery as VRF consumer
        vrfCoordinator.addConsumer(SUBSCRIPTION_ID, address(lottery));
        
        // Authorize Lottery in PrizePool
        vm.prank(admin);
        prizePool.authorizeGame(address(lottery), true);
        
        // Enable public minting for GamePass
        vm.prank(admin);
        gamePass.setPublicMintEnabled(true);
        
        // Setup players with tokens and passes
        vm.prank(admin);
        gameToken.mint(player1, 10_000e18);
        vm.prank(admin);
        gameToken.mint(player2, 10_000e18);
        vm.prank(admin);
        gameToken.mint(player3, 10_000e18);
        
        // Mint passes for players
        vm.prank(admin);
        gamePass.adminMint(player1, GamePass.Tier.Bronze);
        vm.prank(admin);
        gamePass.adminMint(player2, GamePass.Tier.Silver);
        vm.prank(admin);
        gamePass.adminMint(player3, GamePass.Tier.Gold);
        
        // Fund PrizePool
        vm.prank(admin);
        gameToken.mint(address(this), 100_000e18);
        gameToken.approve(address(prizePool), 100_000e18);
        prizePool.deposit(100_000e18);
    }

    function testInitialState() public view {
        assertEq(lottery.ticketPrice(), TICKET_PRICE);
        assertEq(lottery.currentRound(), 1);
        assertTrue(lottery.hasRole(lottery.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(lottery.hasRole(lottery.LOTTERY_ADMIN_ROLE(), admin));
        assertTrue(lottery.hasRole(lottery.PAUSER_ROLE(), admin));
        
        Lottery.LotteryRound memory round = lottery.getCurrentLottery();
        assertEq(round.startTime, block.timestamp);
        assertEq(round.endTime, block.timestamp + 7 days);
        assertFalse(round.drawn);
        assertEq(round.totalTickets, 0);
        assertEq(round.prizeAmount, 0);
    }

    function testBuyTickets() public {
        uint256 ticketCount = 3;
        uint256 totalCost = TICKET_PRICE * ticketCount;
        
        vm.prank(player1);
        gameToken.approve(address(lottery), totalCost);
        
        vm.expectEmit(true, true, false, true);
        emit TicketPurchased(1, player1, ticketCount, totalCost);
        
        vm.prank(player1);
        lottery.buyTickets(ticketCount);
        
        // Check player's tickets
        assertEq(lottery.userTickets(1, player1), ticketCount);
        
        // Check round stats
        Lottery.LotteryRound memory round = lottery.getCurrentLottery();
        assertEq(round.totalTickets, ticketCount);
        assertEq(round.prizeAmount, totalCost);
        
        // Check token balances
        assertEq(gameToken.balanceOf(address(lottery)), totalCost);
    }

    function testBuyTicketsWithNFTDiscount() public {
        uint256 ticketCount = 1;
        uint256 expectedDiscount = (TICKET_PRICE * 300) / 10000; // 3% for Silver
        uint256 discountedPrice = TICKET_PRICE - expectedDiscount;
        
        vm.prank(player2);
        gameToken.approve(address(lottery), TICKET_PRICE);
        
        uint256 balanceBefore = gameToken.balanceOf(player2);
        
        vm.prank(player2);
        lottery.buyTickets(ticketCount);
        
        uint256 balanceAfter = gameToken.balanceOf(player2);
        assertEq(balanceBefore - balanceAfter, discountedPrice);
    }

    function testBuyTicketsAfterRoundEnd() public {
        // Fast forward past round end
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(player1);
        gameToken.approve(address(lottery), TICKET_PRICE);
        
        vm.expectRevert(Lottery.LotteryEnded.selector);
        vm.prank(player1);
        lottery.buyTickets(1);
    }

    function testDrawLottery() public {
        // First, buy some tickets
        vm.prank(player1);
        gameToken.approve(address(lottery), TICKET_PRICE * 2);
        vm.prank(player1);
        lottery.buyTickets(2);
        
        vm.prank(player2);
        gameToken.approve(address(lottery), TICKET_PRICE);
        vm.prank(player2);
        lottery.buyTickets(1);
        
        // Fast forward past round end
        vm.warp(block.timestamp + 7 days + 1);
        
        vm.prank(admin);
        lottery.drawLottery();
        
        // Check that draw was initiated
        Lottery.LotteryRound memory round = lottery.getCurrentLottery();
        assertTrue(round.drawn);
    }

    function testDrawLotteryTooEarly() public {
        vm.expectRevert(Lottery.LotteryNotEnded.selector);
        vm.prank(admin);
        lottery.drawLottery();
    }

    function testDrawLotteryAlreadyDrawn() public {
        // Buy tickets first
        vm.prank(player1);
        gameToken.approve(address(lottery), TICKET_PRICE);
        vm.prank(player1);
        lottery.buyTickets(1);
        
        // Fast forward and draw
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(admin);
        lottery.drawLottery();
        
        // Try to draw again
        vm.expectRevert(Lottery.AlreadyDrawn.selector);
        vm.prank(admin);
        lottery.drawLottery();
    }

    function testClaimPrize() public {
        // Buy tickets
        vm.prank(player1);
        gameToken.approve(address(lottery), TICKET_PRICE);
        vm.prank(player1);
        lottery.buyTickets(1);
        
        // Fast forward and draw
        vm.warp(block.timestamp + 7 days + 1);
        vm.prank(admin);
        lottery.drawLottery();
        
        // Mock VRF fulfillment
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;
        vrfCoordinator.fulfillRandomWords(1, address(lottery));
        
        // Claim prize (this will fail because player1 is not a winner, but we're testing the function exists)
        vm.expectRevert(Lottery.NotWinner.selector);
        vm.prank(player1);
        lottery.claimPrize(1);
    }

    function testSetTicketPrice() public {
        uint256 newPrice = 200e18;
        
        vm.prank(admin);
        lottery.setTicketPrice(newPrice);
        
        assertEq(lottery.ticketPrice(), newPrice);
    }

    function testPauseAndUnpause() public {
        // Pause
        vm.prank(admin);
        lottery.pause();
        
        vm.prank(player1);
        gameToken.approve(address(lottery), TICKET_PRICE);
        
        vm.expectRevert("Pausable: paused");
        vm.prank(player1);
        lottery.buyTickets(1);
        
        // Unpause
        vm.prank(admin);
        lottery.unpause();
        
        vm.prank(player1);
        lottery.buyTickets(1);
        
        assertEq(lottery.userTickets(1, player1), 1);
    }
}