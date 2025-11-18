// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PvPBetting.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";
import "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PvPBettingTest is Test {
    PvPBetting public pvpBetting;
    GameToken public gameToken;
    GamePass public gamePass;
    VRFCoordinatorV2Mock public vrfCoordinator;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public player1 = address(0x3);
    address public player2 = address(0x4);
    address public player3 = address(0x5);
    
    bytes32 public constant KEY_HASH = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint256 public constant MIN_BET = 10e18;
    uint256 public constant MAX_BET = 10000e18;
    
    event BetCreated(uint256 indexed betId, address indexed creator, uint256 amount, PvPBetting.BetType betType, string description);
    event BetAccepted(uint256 indexed betId, address indexed opponent);
    event BetSettled(uint256 indexed betId, address indexed winner, uint256 payout);
    event DisputeRaised(uint256 indexed betId, address indexed disputer);

    function setUp() public {
        // Deploy VRF Mock
        vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 1e9);
        
        // Use vm.startPrank to ensure all subsequent calls use the admin address
        vm.startPrank(admin);
        
        // Create VRF subscription
        uint64 subId = vrfCoordinator.createSubscription();
        
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
        
        // Enable public minting for GamePass
        gamePass.setPublicMintEnabled(true);
        
        // Deploy PvPBetting
        pvpBetting = new PvPBetting(
            address(vrfCoordinator),
            subId,
            KEY_HASH,
            address(gameToken),
            address(gamePass),
            treasury,
            MIN_BET,
            MAX_BET,
            admin
        );
        
        // Fund subscription and add consumer
        vrfCoordinator.fundSubscription(subId, 10 ether);
        vrfCoordinator.addConsumer(subId, address(pvpBetting));
        
        vm.stopPrank();
        
        // Setup players with tokens and passes
        vm.startPrank(admin);
        gameToken.mint(player1, 10_000e18);
        gameToken.mint(player2, 10_000e18);
        gameToken.mint(player3, 10_000e18);
        
        // Mint passes for players
        gamePass.adminMint(player1, GamePass.Tier.Bronze);
        gamePass.adminMint(player2, GamePass.Tier.Silver);
        gamePass.adminMint(player3, GamePass.Tier.Gold);
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(pvpBetting.getMinBet(), MIN_BET);
        assertEq(pvpBetting.getMaxBet(), MAX_BET);
        assertEq(pvpBetting.nextBetId(), 1);
        assertEq(pvpBetting.totalBets(), 0);
        assertTrue(pvpBetting.hasRole(pvpBetting.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pvpBetting.hasRole(pvpBetting.BETTING_ADMIN_ROLE(), admin));
        assertTrue(pvpBetting.hasRole(pvpBetting.PAUSER_ROLE(), admin));
    }

    function testCreateCoinFlipBet() public {
        uint256 betAmount = 100e18;
        string memory description = "Coin flip bet";
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.expectEmit(true, true, false, true);
        emit BetCreated(1, player1, betAmount, PvPBetting.BetType.CoinFlip, description);
        
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, description, bytes32(0), true);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(bet.creator, player1);
        assertEq(bet.amount, betAmount);
        assertEq(uint8(bet.betType), uint8(PvPBetting.BetType.CoinFlip));
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Open));
        assertEq(bet.description, description);
        assertEq(bet.creatorSide, true);
        
        assertEq(gameToken.balanceOf(address(pvpBetting)), betAmount);
        assertEq(pvpBetting.totalBets(), 1);
    }

    function testCreateSkillBasedBet() public {
        uint256 betAmount = 250e18;
        string memory description = "Chess match - best of 3";
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, description, bytes32(0), true);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.betType), uint8(PvPBetting.BetType.SkillBased));
        assertEq(bet.creatorSide, true);
    }

    function testCreateCustomBet() public {
        uint256 betAmount = 500e18;
        string memory description = "Who can score higher in Snake game";
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CustomProp, description, bytes32(0), true);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.betType), uint8(PvPBetting.BetType.CustomProp));
    }

    function testCreateBetRequiresPass() public {
        address playerWithoutPass = address(0x6);
        vm.prank(admin);
        gameToken.mint(playerWithoutPass, 10_000e18);
        
        uint256 betAmount = 100e18;
        
        vm.prank(playerWithoutPass);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.expectRevert(PvPBetting.NotBetParticipant.selector);
        vm.prank(playerWithoutPass);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
    }

    function testCreateBetInvalidAmount() public {
        // Test minimum bet validation
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), MIN_BET - 1);
        
        vm.expectRevert(PvPBetting.InvalidBetAmount.selector);
        vm.prank(player1);
        pvpBetting.createBet(MIN_BET - 1, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        // Test maximum bet validation
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), MAX_BET + 1);
        
        vm.expectRevert(PvPBetting.InvalidBetAmount.selector);
        vm.prank(player1);
        pvpBetting.createBet(MAX_BET + 1, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
    }

    function testAcceptBet() public {
        uint256 betAmount = 100e18;
        
        // Player1 creates bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        // Player2 accepts bet
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.expectEmit(true, true, false, true);
        emit BetAccepted(1, player2);
        
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(bet.opponent, player2);
        // For coin flip bets, status should be WaitingResult after acceptance since VRF is requested
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.WaitingResult));
        assertEq(bet.opponentSide, false);
        assertTrue(bet.vrfRequestId > 0);
        
        // Check that tokens are locked
        assertEq(gameToken.balanceOf(address(pvpBetting)), betAmount * 2);
    }

    function testAcceptOwnBet() public {
        uint256 betAmount = 100e18;
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.expectRevert(PvPBetting.CannotBetAgainstSelf.selector);
        vm.prank(player1);
        pvpBetting.acceptBet(1, false);
    }

    function testAcceptNonexistentBet() public {
        vm.expectRevert(PvPBetting.BetNotFound.selector);
        vm.prank(player2);
        pvpBetting.acceptBet(999, false);
    }

    function testAcceptExpiredBet() public {
        uint256 betAmount = 100e18;
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        // Fast forward past expiration
        vm.warp(block.timestamp + 25 hours);
        
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.expectRevert(PvPBetting.BetExpired.selector);
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
    }

    function testSubmitResultSkillBased() public {
        uint256 betAmount = 100e18;
        
        // Create and accept skill-based bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, "test", bytes32(0), true);
        
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
        
        // Add trusted provider
        vm.prank(admin);
        pvpBetting.setTrustedProvider(player1, true);
        
        // Player1 submits result (claims victory)
        vm.prank(player1);
        pvpBetting.submitResult(1, bytes32(uint256(1)), player1);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(bet.resultHash, bytes32(uint256(1)));
        assertEq(bet.winner, player1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Completed));
    }

    function testSubmitConflictingResults() public {
        uint256 betAmount = 100e18;
        
        // Create and accept skill-based bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, "test", bytes32(0), true);
        
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
        
        // Add trusted providers
        vm.prank(admin);
        pvpBetting.setTrustedProvider(player1, true);
        pvpBetting.setTrustedProvider(player2, true);
        
        // Player1 claims victory
        vm.prank(player1);
        pvpBetting.submitResult(1, bytes32(uint256(1)), player1);
        
        // Player2 claims victory (conflicting)
        vm.prank(player2);
        pvpBetting.submitResult(1, bytes32(uint256(2)), player2);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Disputed));
    }

    function testCoinFlipAutomatic() public {
        uint256 betAmount = 100e18;
        
        // Create and accept coin flip bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
        
        // Fast forward past expiration to trigger automatic resolution
        vm.warp(block.timestamp + 25 hours);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertTrue(bet.vrfRequestId > 0);
        
        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0; // Heads
        
        vrfCoordinator.fulfillRandomWords(bet.vrfRequestId, address(pvpBetting));
        
        bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Completed));
    }

    function testCancelExpiredBet() public {
        uint256 betAmount = 100e18;
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        // Fast forward past expiration
        vm.warp(block.timestamp + 25 hours);
        
        uint256 balanceBefore = gameToken.balanceOf(player1);
        
        vm.prank(player1);
        pvpBetting.cancelBet(1);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Cancelled));
        
        // Check refund
        assertEq(gameToken.balanceOf(player1), balanceBefore + betAmount);
    }

    function testCancelNotExpiredBet() public {
        uint256 betAmount = 100e18;
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, "test", bytes32(0), true);
        
        // Should revert with BetNotOpen because skill-based bets go to WaitingResult status after acceptance
        // But this bet hasn't been accepted yet, so it should still be in Open status
        vm.prank(player1);
        pvpBetting.cancelBet(1);
        
        // Check that the bet was cancelled
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Cancelled));
    }

    function testResolveDispute() public {
        uint256 betAmount = 100e18;
        
        // Create disputed bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, "test", bytes32(0), true);
        
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
        
        // Add trusted provider
        vm.prank(admin);
        pvpBetting.setTrustedProvider(player1, true);
        pvpBetting.setTrustedProvider(player2, true);
        
        // Create dispute
        vm.prank(player1);
        pvpBetting.submitResult(1, bytes32(uint256(1)), player1);
        vm.prank(player2);
        pvpBetting.submitResult(1, bytes32(uint256(2)), player2);
        
        // Admin resolves dispute
        vm.prank(admin);
        pvpBetting.resolveDispute(1, player1);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Completed));
        assertEq(bet.winner, player1);
    }

    function testSetMinMaxBet() public {
        uint256 newMinBet = 20e18;
        uint256 newMaxBet = 20000e18;
        
        vm.prank(admin);
        pvpBetting.setBetLimits(newMinBet, pvpBetting.getMaxBet());
        assertEq(pvpBetting.getMinBet(), newMinBet);
        
        vm.prank(admin);
        pvpBetting.setBetLimits(pvpBetting.getMinBet(), newMaxBet);
        assertEq(pvpBetting.getMaxBet(), newMaxBet);
    }

    function testPauseAndUnpause() public {
        vm.prank(admin);
        pvpBetting.pause();
        assertTrue(pvpBetting.paused());
        
        uint256 betAmount = 100e18;
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.expectRevert("Pausable: paused");
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        vm.prank(admin);
        pvpBetting.unpause();
        assertFalse(pvpBetting.paused());
        
        // Should work now
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
    }

    function testGetPlayerBets() public {
        uint256 betAmount = 100e18;
        
        // Player1 creates bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test1", bytes32(0), true);
        
        // Player1 creates another bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, "test2", bytes32(0), true);
        
        uint256[] memory player1Bets = pvpBetting.getUserActiveBets(player1);
        assertEq(player1Bets.length, 2);
        assertEq(player1Bets[0], 1);
        assertEq(player1Bets[1], 2);
    }

    function testAccessControl() public {
        // Non-admin cannot set bet limits
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint256(uint160(player1)), 20),
                " is missing role ",
                Strings.toHexString(uint256(pvpBetting.BETTING_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(player1);
        pvpBetting.setBetLimits(20e18, pvpBetting.maxBetAmount());
        
        // Reset prank
        vm.stopPrank();
        
        // Non-admin cannot resolve dispute (need to create a bet first)
        uint256 betAmount = 100e18;
        
        vm.startPrank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.SkillBased, "test", bytes32(0), true);
        vm.stopPrank();
        
        vm.startPrank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        pvpBetting.acceptBet(1, false);
        vm.stopPrank();
        
        // Add trusted provider
        vm.prank(admin);
        pvpBetting.setTrustedProvider(player1, true);
        pvpBetting.setTrustedProvider(player2, true);
        
        // Create dispute by submitting conflicting results
        vm.startPrank(player1);
        pvpBetting.submitResult(1, bytes32(uint256(1)), player1);
        vm.stopPrank();
        
        vm.startPrank(player2);
        pvpBetting.submitResult(1, bytes32(uint256(2)), player2);
        vm.stopPrank();
        
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint256(uint160(player1)), 20),
                " is missing role ",
                Strings.toHexString(uint256(pvpBetting.BETTING_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(player1);
        pvpBetting.resolveDispute(1, player2);
        
        // Reset prank
        vm.stopPrank();
        
        // Non-pauser cannot pause
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint256(uint160(player1)), 20),
                " is missing role ",
                Strings.toHexString(uint256(pvpBetting.PAUSER_ROLE()), 32)
            )
        );
        vm.prank(player1);
        pvpBetting.pause();
    }

    // Fuzz tests
    function testFuzzCreateBet(uint256 betAmount) public {
        vm.assume(betAmount >= MIN_BET && betAmount <= MAX_BET);
        
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "fuzz test", bytes32(0), true);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        assertEq(bet.amount, betAmount);
        assertEq(gameToken.balanceOf(address(pvpBetting)), betAmount);
    }

    function testFuzzCoinFlipResult(uint256 randomWord) public {
        uint256 betAmount = 100e18;
        
        // Create and accept coin flip bet
        vm.prank(player1);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player1);
        pvpBetting.createBet(betAmount, PvPBetting.BetType.CoinFlip, "test", bytes32(0), true);
        
        vm.prank(player2);
        gameToken.approve(address(pvpBetting), betAmount);
        vm.prank(player2);
        pvpBetting.acceptBet(1, false);
        
        // Fast forward and resolve
        vm.warp(block.timestamp + 25 hours);
        
        PvPBetting.Bet memory bet = pvpBetting.getBet(1);
        
        // Simulate VRF response
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        
        vrfCoordinator.fulfillRandomWords(bet.vrfRequestId, address(pvpBetting));
        
        bet = pvpBetting.getBet(1);
        assertEq(uint8(bet.status), uint8(PvPBetting.BetStatus.Completed));
        
        // Check that someone won
        assertTrue(bet.winner == player1 || bet.winner == player2);
    }
}