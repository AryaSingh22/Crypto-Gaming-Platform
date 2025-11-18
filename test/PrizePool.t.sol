// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PrizePool.sol";
import "../src/GameToken.sol";

contract PrizePoolTest is Test {
    PrizePool public prizePool;
    GameToken public gameToken;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public gameContract = address(0x3);
    address public player = address(0x4);
    address public depositor = address(0x5);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint16 public constant INITIAL_FEE_BPS = 200; // 2%
    
    event Deposited(address indexed from, uint256 amount);
    event Payout(address indexed to, uint256 grossWin, uint256 fee, uint256 netWin);
    event FeeUpdated(uint16 newFeeBps);
    event GameAuthorized(address indexed game, bool authorized);

    function setUp() public {
        // Deploy GameToken
        gameToken = new GameToken(
            "Game Token",
            "GAME",
            INITIAL_SUPPLY,
            0, // No max supply
            treasury,
            admin
        );
        
        // Deploy PrizePool
        prizePool = new PrizePool(
            address(gameToken),
            treasury,
            INITIAL_FEE_BPS,
            admin
        );
        
        // Authorize game contract
        vm.prank(admin);
        prizePool.authorizeGame(gameContract, true);
        
        // Give some tokens to depositor
        vm.prank(admin);
        gameToken.mint(depositor, 100_000e18);
        
        // Give some tokens to treasury for initial deposit
        vm.prank(treasury);
        gameToken.approve(address(prizePool), INITIAL_SUPPLY);
    }

    function testInitialState() public view{
        assertEq(address(prizePool.gameToken()), address(gameToken));
        assertEq(prizePool.treasury(), treasury);
        assertEq(prizePool.feeBps(), INITIAL_FEE_BPS);
        assertTrue(prizePool.authorizedGames(gameContract));
        assertTrue(prizePool.hasRole(prizePool.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(prizePool.hasRole(prizePool.TREASURER_ROLE(), admin));
        assertTrue(prizePool.hasRole(prizePool.PAUSER_ROLE(), admin));
    }

    function testDeposit() public {
        uint256 depositAmount = 10_000e18;
        
        vm.prank(depositor);
        gameToken.approve(address(prizePool), depositAmount);
        
        vm.expectEmit(true, false, false, true);
        emit Deposited(depositor, depositAmount);
        
        vm.prank(depositor);
        prizePool.deposit(depositAmount);
        
        assertEq(prizePool.getAvailableBalance(), depositAmount);
        assertEq(gameToken.balanceOf(address(prizePool)), depositAmount);
    }

    function testDepositZeroAmount() public {
        vm.expectRevert(PrizePool.ZeroAmount.selector);
        vm.prank(depositor);
        prizePool.deposit(0);
    }

    function testPayout() public {
        uint256 depositAmount = 10_000e18;
        uint256 grossWin = 1_000e18;
        uint256 expectedFee = (grossWin * INITIAL_FEE_BPS) / 10000; // 2%
        uint256 expectedNetWin = grossWin - expectedFee;
        
        // First deposit some funds
        vm.prank(depositor);
        gameToken.approve(address(prizePool), depositAmount);
        vm.prank(depositor);
        prizePool.deposit(depositAmount);
        
        uint256 treasuryBalanceBefore = gameToken.balanceOf(treasury);
        uint256 playerBalanceBefore = gameToken.balanceOf(player);
        
        vm.expectEmit(true, false, false, true);
        emit Payout(player, grossWin, expectedFee, expectedNetWin);
        
        vm.prank(gameContract);
        prizePool.payout(player, grossWin);
        
        assertEq(gameToken.balanceOf(player), playerBalanceBefore + expectedNetWin);
        assertEq(gameToken.balanceOf(treasury), treasuryBalanceBefore + expectedFee);
        assertEq(prizePool.totalPayouts(), grossWin);
        assertEq(prizePool.totalFeesCollected(), expectedFee);
        assertEq(prizePool.getAvailableBalance(), depositAmount - grossWin);
    }

    function testPayoutFromUnauthorizedGame() public {
        vm.expectRevert(PrizePool.UnauthorizedGame.selector);
        vm.prank(player);
        prizePool.payout(player, 1000e18);
    }

    function testPayoutZeroAmount() public {
        vm.expectRevert(PrizePool.ZeroAmount.selector);
        vm.prank(gameContract);
        prizePool.payout(player, 0);
    }

    function testPayoutToZeroAddress() public {
        vm.expectRevert(PrizePool.ZeroAddress.selector);
        vm.prank(gameContract);
        prizePool.payout(address(0), 1000e18);
    }

    function testPayoutInsufficientBalance() public {
        uint256 grossWin = 1000e18;
        
        vm.expectRevert(PrizePool.InsufficientBalance.selector);
        vm.prank(gameContract);
        prizePool.payout(player, grossWin);
    }

    function testAuthorizeGame() public {
        address newGame = address(0x6);
        
        assertFalse(prizePool.isGameAuthorized(newGame));
        
        vm.expectEmit(true, false, false, true);
        emit GameAuthorized(newGame, true);
        
        vm.prank(admin);
        prizePool.authorizeGame(newGame, true);
        
        assertTrue(prizePool.isGameAuthorized(newGame));
        
        // Deauthorize
        vm.expectEmit(true, false, false, true);
        emit GameAuthorized(newGame, false);
        
        vm.prank(admin);
        prizePool.authorizeGame(newGame, false);
        
        assertFalse(prizePool.isGameAuthorized(newGame));
    }

    function testAuthorizeGameZeroAddress() public {
        vm.expectRevert(PrizePool.ZeroAddress.selector);
        vm.prank(admin);
        prizePool.authorizeGame(address(0), true);
    }

    function testSetFeeBps() public {
        uint16 newFeeBps = 500; // 5%
        
        vm.expectEmit(false, false, false, true);
        emit FeeUpdated(newFeeBps);
        
        vm.prank(admin);
        prizePool.setFeeBps(newFeeBps);
        
        assertEq(prizePool.feeBps(), newFeeBps);
    }

    function testSetFeeBpsInvalid() public {
        uint16 invalidFeeBps = 1001; // > 10%
        
        vm.expectRevert(PrizePool.InvalidFee.selector);
        vm.prank(admin);
        prizePool.setFeeBps(invalidFeeBps);
    }

    function testSetTreasury() public {
        address newTreasury = address(0x7);
        
        vm.prank(admin);
        prizePool.setTreasury(newTreasury);
        
        assertEq(prizePool.treasury(), newTreasury);
    }

    function testSetTreasuryZeroAddress() public {
        vm.expectRevert(PrizePool.ZeroAddress.selector);
        vm.prank(admin);
        prizePool.setTreasury(address(0));
    }

    function testWithdrawTreasury() public {
        uint256 depositAmount = 10_000e18;
        uint256 withdrawAmount = 5_000e18;
        
        // Deposit funds
        vm.prank(depositor);
        gameToken.approve(address(prizePool), depositAmount);
        vm.prank(depositor);
        prizePool.deposit(depositAmount);
        
        uint256 treasuryBalanceBefore = gameToken.balanceOf(treasury);
        
        vm.prank(admin);
        prizePool.withdrawTreasury(withdrawAmount);
        
        assertEq(gameToken.balanceOf(treasury), treasuryBalanceBefore + withdrawAmount);
        assertEq(prizePool.getAvailableBalance(), depositAmount - withdrawAmount);
    }

    function testWithdrawTreasuryInsufficientBalance() public {
        uint256 withdrawAmount = 1000e18;
        
        vm.expectRevert(PrizePool.InsufficientBalance.selector);
        vm.prank(admin);
        prizePool.withdrawTreasury(withdrawAmount);
    }

    function testEmergencyWithdraw() public {
        uint256 depositAmount = 10_000e18;
        uint256 withdrawAmount = 5_000e18;
        
        // Deposit funds
        vm.prank(depositor);
        gameToken.approve(address(prizePool), depositAmount);
        vm.prank(depositor);
        prizePool.deposit(depositAmount);
        
        // Pause contract
        vm.prank(admin);
        prizePool.pause();
        
        uint256 adminBalanceBefore = gameToken.balanceOf(admin);
        
        vm.prank(admin);
        prizePool.emergencyWithdraw(admin, withdrawAmount);
        
        assertEq(gameToken.balanceOf(admin), adminBalanceBefore + withdrawAmount);
        assertEq(prizePool.getAvailableBalance(), depositAmount - withdrawAmount);
    }

    function testEmergencyWithdrawNotPaused() public {
        // Cannot emergency withdraw when not paused
        vm.expectRevert("Pausable: not paused");
        vm.prank(admin);
        prizePool.emergencyWithdraw(admin, 1000e18);
    }

    function testPauseAndUnpause() public {
        // Pause contract
        vm.prank(admin);
        prizePool.pause();
        assertTrue(prizePool.paused());
        
        // Try to deposit while paused
        vm.expectRevert("Pausable: paused");
        vm.prank(depositor);
        prizePool.deposit(1000e18);
        
        // Try to payout while paused
        vm.expectRevert("Pausable: paused");
        vm.prank(gameContract);
        prizePool.payout(player, 1000e18);
        
        // Unpause
        vm.prank(admin);
        prizePool.unpause();
        assertFalse(prizePool.paused());
        
        // Should work now
        vm.prank(depositor);
        gameToken.approve(address(prizePool), 1000e18);
        vm.prank(depositor);
        prizePool.deposit(1000e18);
        
        assertEq(prizePool.getAvailableBalance(), 1000e18);
    }

    function testGetFeePercentage() public {
        assertEq(prizePool.getFeePercentage(), 2); // 2%
        
        vm.prank(admin);
        prizePool.setFeeBps(500); // 5%
        
        assertEq(prizePool.getFeePercentage(), 5);
    }

    function testCalculatePayout() public view{
        uint256 grossWin = 1000e18;
        (uint256 fee, uint256 netWin) = prizePool.calculatePayout(grossWin);
        
        uint256 expectedFee = (grossWin * INITIAL_FEE_BPS) / 10000;
        uint256 expectedNetWin = grossWin - expectedFee;
        
        assertEq(fee, expectedFee);
        assertEq(netWin, expectedNetWin);
    }

    function testGetStats() public {
        uint256 depositAmount = 10_000e18;
        uint256 grossWin = 1_000e18;
        
        // Deposit funds
        vm.prank(depositor);
        gameToken.approve(address(prizePool), depositAmount);
        vm.prank(depositor);
        prizePool.deposit(depositAmount);
        
        // Make a payout
        vm.prank(gameContract);
        prizePool.payout(player, grossWin);
        
        (
            uint256 balance,
            uint256 totalPayoutsMade,
            uint256 totalFeesCollected_,
            uint16 currentFeeBps
        ) = prizePool.getStats();
        
        assertEq(balance, depositAmount - grossWin);
        assertEq(totalPayoutsMade, grossWin);
        assertEq(totalFeesCollected_, (grossWin * INITIAL_FEE_BPS) / 10000);
        assertEq(currentFeeBps, INITIAL_FEE_BPS);
    }

    function testAccessControl() public {
        // Non-admin cannot authorize games
        vm.expectRevert();
        vm.prank(player);
        prizePool.authorizeGame(address(0x8), true);
        
        // Non-admin cannot set fee
        vm.expectRevert();
        vm.prank(player);
        prizePool.setFeeBps(300);
        
        // Non-treasurer cannot withdraw treasury
        vm.expectRevert();
        vm.prank(player);
        prizePool.withdrawTreasury(1000e18);
        
        // Non-pauser cannot pause
        vm.expectRevert();
        vm.prank(player);
        prizePool.pause();
    }

    function testConstructorValidation() public {
        // Zero game token address
        vm.expectRevert(PrizePool.ZeroAddress.selector);
        new PrizePool(address(0), treasury, INITIAL_FEE_BPS, admin);
        
        // Zero treasury address
        vm.expectRevert(PrizePool.ZeroAddress.selector);
        new PrizePool(address(gameToken), address(0), INITIAL_FEE_BPS, admin);
        
        // Zero admin address
        vm.expectRevert(PrizePool.ZeroAddress.selector);
        new PrizePool(address(gameToken), treasury, INITIAL_FEE_BPS, address(0));
        
        // Invalid fee
        vm.expectRevert(PrizePool.InvalidFee.selector);
        new PrizePool(address(gameToken), treasury, 1001, admin);
    }

    // Fuzz tests
    function testFuzzPayout(uint256 grossWin) public {
        vm.assume(grossWin > 0 && grossWin <= 50_000e18);
        
        uint256 depositAmount = 100_000e18;
        
        // Deposit funds
        vm.prank(depositor);
        gameToken.approve(address(prizePool), depositAmount);
        vm.prank(depositor);
        prizePool.deposit(depositAmount);
        
        uint256 expectedFee = (grossWin * INITIAL_FEE_BPS) / 10000;
        uint256 expectedNetWin = grossWin - expectedFee;
        
        uint256 treasuryBalanceBefore = gameToken.balanceOf(treasury);
        uint256 playerBalanceBefore = gameToken.balanceOf(player);
        
        vm.prank(gameContract);
        prizePool.payout(player, grossWin);
        
        assertEq(gameToken.balanceOf(player), playerBalanceBefore + expectedNetWin);
        assertEq(gameToken.balanceOf(treasury), treasuryBalanceBefore + expectedFee);
        assertEq(prizePool.totalPayouts(), grossWin);
        assertEq(prizePool.totalFeesCollected(), expectedFee);
    }

    function testFuzzFeeBps(uint16 feeBps) public {
        vm.assume(feeBps <= 1000); // Max 10%
        
        vm.prank(admin);
        prizePool.setFeeBps(feeBps);
        
        assertEq(prizePool.feeBps(), feeBps);
        
        uint256 grossWin = 1000e18;
        (uint256 fee, uint256 netWin) = prizePool.calculatePayout(grossWin);
        
        uint256 expectedFee = (grossWin * feeBps) / 10000;
        uint256 expectedNetWin = grossWin - expectedFee;
        
        assertEq(fee, expectedFee);
        assertEq(netWin, expectedNetWin);
    }

    function testFuzzDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 50_000e18);
        
        vm.prank(admin);
        gameToken.mint(depositor, amount);
        
        vm.prank(depositor);
        gameToken.approve(address(prizePool), amount);
        
        vm.prank(depositor);
        prizePool.deposit(amount);
        
        assertEq(prizePool.getAvailableBalance(), amount);
    }
}