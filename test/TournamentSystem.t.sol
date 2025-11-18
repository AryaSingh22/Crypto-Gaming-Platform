// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/tournaments/TournamentSystem.sol";
import "../src/GameToken.sol";
import "../src/MonitoringSystem.sol";

contract TournamentSystemTest is Test {
    TournamentSystem public tournamentSystem;
    GameToken public gameToken;
    MonitoringSystem public monitoringSystem;
    
    address public admin = address(0x1);
    address public player1 = address(0x2);
    address public player2 = address(0x3);
    address public treasury = address(0x4);

    function setUp() public {
        vm.startPrank(admin);
        
        gameToken = new GameToken("Game Token", "GAME", 1_000_000e18, 0, admin, admin);
        monitoringSystem = new MonitoringSystem();
        
        tournamentSystem = new TournamentSystem(
            address(gameToken),
            treasury,
            address(monitoringSystem)
        );
        
        // Setup roles
        tournamentSystem.grantRole(tournamentSystem.TOURNAMENT_ADMIN_ROLE(), admin);
        
        vm.stopPrank();
        
        // Fund players
        vm.prank(admin);
        gameToken.mint(player1, 1000e18);
        vm.prank(admin);
        gameToken.mint(player2, 1000e18);
    }

    function testCreateTournament() public {
        vm.prank(admin);
        uint256 tournamentId = tournamentSystem.createTournament(
            "Test Tournament",
            100e18, // Entry fee
            1000e18, // Prize pool
            10, // Max participants
            block.timestamp + 3600, // Start time
            block.timestamp + 7200 // End time
        );
        
        assertEq(tournamentId, 1);
        
        TournamentSystem.Tournament memory t = tournamentSystem.getTournament(tournamentId);
        assertEq(t.name, "Test Tournament");
        assertEq(t.entryFee, 100e18);
    }

    function testJoinTournament() public {
        vm.prank(admin);
        uint256 tournamentId = tournamentSystem.createTournament(
            "Test Tournament",
            100e18,
            1000e18,
            10,
            block.timestamp + 3600,
            block.timestamp + 7200
        );
        
        vm.startPrank(player1);
        gameToken.approve(address(tournamentSystem), 100e18);
        tournamentSystem.joinTournament(tournamentId);
        vm.stopPrank();
        
        assertEq(tournamentSystem.getParticipantCount(tournamentId), 1);
    }
}
