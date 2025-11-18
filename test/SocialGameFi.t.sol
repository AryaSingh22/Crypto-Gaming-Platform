// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/social/SocialGameFi.sol";
import "../src/GameToken.sol";
import "../src/MonitoringSystem.sol";

contract SocialGameFiTest is Test {
    SocialGameFi public social;
    GameToken public gameToken;
    MonitoringSystem public monitoringSystem;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public treasury = address(0x4);

    function setUp() public {
        vm.startPrank(admin);
        
        gameToken = new GameToken("Game Token", "GAME", 1_000_000e18, 0, admin, admin);
        monitoringSystem = new MonitoringSystem();
        
        social = new SocialGameFi(
            address(gameToken),
            treasury,
            address(monitoringSystem)
        );
        
        vm.stopPrank();
    }

    function testCreateProfile() public {
        vm.prank(user1);
        social.createProfile("User1", "Bio", "Avatar");
        
        (string memory username, , , ) = social.getProfile(user1);
        assertEq(username, "User1");
    }
}
