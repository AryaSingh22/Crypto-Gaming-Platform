// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/ReferralSystem.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";

contract ReferralSystemTest is Test {
    ReferralSystem public referralSystem;
    GameToken public gameToken;
    GamePass public gamePass;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public user3 = address(0x5);
    address public gameContract = address(0x6);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    
    event UserRegistered(address indexed user, address indexed referrer, string referralCode);
    event ActivityRecorded(address indexed user, address indexed referrer, ReferralSystem.ActivityType activityType, uint256 volume, uint256 rewards);
    event RewardsPaid(address indexed referrer, address indexed referee, uint256 amount, ReferralSystem.ActivityType activityType);
    event TierUpgraded(address indexed user, uint256 oldTier, uint256 newTier);
    event ReferralCodeUpdated(address indexed user, string oldCode, string newCode);

    function setUp() public {
        // Use vm.startPrank to ensure all subsequent calls use the admin address
        vm.startPrank(admin);
        
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
        
        // Deploy ReferralSystem
        referralSystem = new ReferralSystem(
            address(gameToken),
            address(gamePass),
            treasury,
            admin
        );
        
        // Grant activity recorder role to game contract
        referralSystem.grantRole(referralSystem.ACTIVITY_RECORDER_ROLE(), gameContract);
        
        vm.stopPrank();
        
        // Setup treasury with tokens for rewards
        vm.startPrank(admin);
        gameToken.mint(treasury, 100_000e18);
        vm.stopPrank();
        
        vm.startPrank(treasury);
        gameToken.approve(address(referralSystem), 100_000e18);
        vm.stopPrank();
        
        // Setup users with tokens
        vm.startPrank(admin);
        gameToken.mint(user1, 10_000e18);
        gameToken.mint(user2, 10_000e18);
        gameToken.mint(user3, 10_000e18);
        
        // Mint NFT passes for users
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        gamePass.adminMint(user2, GamePass.Tier.Silver);
        gamePass.adminMint(user3, GamePass.Tier.Gold);
        vm.stopPrank();
    }

    function testInitialState() public view{
        assertEq(referralSystem.totalReferrals(), 0);
        assertEq(referralSystem.totalRewardsPaid(), 0);
        assertEq(referralSystem.activeUsers(), 0);
        assertEq(referralSystem.minimumActivityVolume(), 10e18);
        assertEq(referralSystem.maxRewardPerActivity(), 1000e18);
        
        // Check default activity reward rates
        assertEq(referralSystem.activityRewardRates(ReferralSystem.ActivityType.GamePlay), 200); // 2%
        assertEq(referralSystem.activityRewardRates(ReferralSystem.ActivityType.NFTTrading), 150); // 1.5%
        assertEq(referralSystem.activityRewardRates(ReferralSystem.ActivityType.Staking), 100); // 1%
        
        // Check NFT tier multipliers
        assertEq(referralSystem.tierMultipliers(GamePass.Tier.Bronze), 10000); // 1x
        assertEq(referralSystem.tierMultipliers(GamePass.Tier.Silver), 12000); // 1.2x
        assertEq(referralSystem.tierMultipliers(GamePass.Tier.Gold), 15000); // 1.5x
        
        // Check default referral tiers
        (uint256 minReferrals, uint256 rewardRate, uint256 bonusRate, string memory name) = referralSystem.referralTiers(0);
        assertEq(minReferrals, 0);
        assertEq(rewardRate, 200);
        assertEq(bonusRate, 0);
        assertEq(name, "Starter");
    }

    function testRegisterWithoutReferral() public {
        string memory userCode = "USER1_CODE";
        
        vm.expectEmit(true, true, false, true);
        emit UserRegistered(user1, address(0), userCode);
        
        vm.prank(user1);
        referralSystem.registerWithReferral("", userCode);
        
        // Check user registration
        ReferralSystem.ReferralData memory userData = referralSystem.getUserReferralData(user1);
        assertEq(userData.referrer, address(0));
        assertTrue(userData.isActive);
        assertEq(userData.registrationTime, block.timestamp);
        
        // Check referral code mapping
        assertEq(referralSystem.referralCodes(userCode), user1);
        assertEq(referralSystem.userReferralCodes(user1), userCode);
        
        // Check global stats
        assertEq(referralSystem.totalReferrals(), 1);
        assertEq(referralSystem.activeUsers(), 1);
    }

    function testRegisterWithReferral() public {
        string memory referrerCode = "REFERRER_CODE";
        string memory userCode = "USER2_CODE";
        
        // Register referrer first
        vm.prank(user1);
        referralSystem.registerWithReferral("", referrerCode);
        
        vm.expectEmit(true, true, false, true);
        emit UserRegistered(user2, user1, userCode);
        
        vm.prank(user2);
        referralSystem.registerWithReferral(referrerCode, userCode);
        
        // Check user registration
        ReferralSystem.ReferralData memory userData = referralSystem.getUserReferralData(user2);
        assertEq(userData.referrer, user1);
        assertTrue(userData.isActive);
        
        // Check referrer's stats updated
        ReferralSystem.ReferralData memory referrerData = referralSystem.getUserReferralData(user1);
        assertEq(referrerData.totalReferrals, 1);
        assertEq(referrerData.activeReferrals, 1);
        
        // Check global stats
        assertEq(referralSystem.totalReferrals(), 2);
        assertEq(referralSystem.activeUsers(), 2);
    }

    function testRegisterInvalidReferralCode() public {
        string memory invalidCode = "INVALID_CODE";
        string memory userCode = "USER_CODE";
        
        vm.expectRevert(ReferralSystem.InvalidReferrer.selector);
        vm.prank(user1);
        referralSystem.registerWithReferral(invalidCode, userCode);
    }

    function testRegisterSelfReferral() public {
        string memory userCode = "USER_CODE";
        
        // First register the user
        vm.prank(user1);
        referralSystem.registerWithReferral("", userCode);
        
        // Now try to register again with self-referral
        vm.expectRevert(ReferralSystem.SelfReferralNotAllowed.selector);
        vm.prank(user1);
        referralSystem.registerWithReferral(userCode, "NEW_CODE");
    }

    function testRegisterDuplicateCode() public {
        string memory userCode = "DUPLICATE_CODE";
        
        // Register first user
        vm.prank(user1);
        referralSystem.registerWithReferral("", userCode);
        
        vm.expectRevert(ReferralSystem.CodeAlreadyExists.selector);
        vm.prank(user2);
        referralSystem.registerWithReferral("", userCode);
    }

    function testRegisterAlreadyRegistered() public {
        string memory userCode = "USER_CODE";
        
        vm.prank(user1);
        referralSystem.registerWithReferral("", userCode);
        
        string memory newCode = "NEW_CODE";
        
        vm.expectRevert(ReferralSystem.UserAlreadyRegistered.selector);
        vm.prank(user1);
        referralSystem.registerWithReferral("", newCode);
    }

    function testRecordActivity() public {
        // Setup referral relationship
        vm.prank(user1);
        referralSystem.registerWithReferral("", "REFERRER_CODE");
        
        vm.prank(user2);
        referralSystem.registerWithReferral("REFERRER_CODE", "USER_CODE");
        
        uint256 activityVolume = 100e18;
        uint256 expectedBaseReward = (activityVolume * 200) / 10000; // 2% for GamePlay
        uint256 expectedBronzeMultiplier = (expectedBaseReward * 10000) / 10000; // 1x for Bronze
        
        uint256 referrerBalanceBefore = gameToken.balanceOf(user1);
        
        vm.expectEmit(true, true, false, true);
        emit ActivityRecorded(user2, user1, ReferralSystem.ActivityType.GamePlay, activityVolume, expectedBronzeMultiplier);
        
        vm.prank(gameContract);
        referralSystem.recordActivity(user2, ReferralSystem.ActivityType.GamePlay, activityVolume);
        
        // Check referrer received rewards
        assertEq(gameToken.balanceOf(user1), referrerBalanceBefore + expectedBronzeMultiplier);
        
        // Check referrer's data updated
        ReferralSystem.ReferralData memory referrerData = referralSystem.getUserReferralData(user1);
        assertEq(referrerData.totalRewards, expectedBronzeMultiplier);
        assertEq(referrerData.totalVolume, activityVolume);
    }

    function testRecordActivityWithNFTMultiplier() public {
        // Setup referral relationship with user3 (Gold NFT) as referrer
        vm.prank(user3);
        referralSystem.registerWithReferral("", "GOLD_REFERRER");
        
        vm.prank(user2);
        referralSystem.registerWithReferral("GOLD_REFERRER", "USER_CODE");
        
        uint256 activityVolume = 100e18;
        uint256 expectedBaseReward = (activityVolume * 200) / 10000; // 2% for GamePlay
        uint256 expectedGoldMultiplier = (expectedBaseReward * 15000) / 10000; // 1.5x for Gold
        
        uint256 referrerBalanceBefore = gameToken.balanceOf(user3);
        
        vm.prank(gameContract);
        referralSystem.recordActivity(user2, ReferralSystem.ActivityType.GamePlay, activityVolume);
        
        // Check referrer received enhanced rewards due to Gold NFT
        assertEq(gameToken.balanceOf(user3), referrerBalanceBefore + expectedGoldMultiplier);
    }

    function testRecordActivityInsufficientVolume() public {
        vm.prank(user1);
        referralSystem.registerWithReferral("", "REFERRER_CODE");
        
        vm.prank(user2);
        referralSystem.registerWithReferral("REFERRER_CODE", "USER_CODE");
        
        uint256 lowVolume = 5e18; // Below minimum
        
        vm.expectRevert(ReferralSystem.InsufficientVolume.selector);
        vm.prank(gameContract);
        referralSystem.recordActivity(user2, ReferralSystem.ActivityType.GamePlay, lowVolume);
    }

    function testRecordActivityNoReferrer() public {
        vm.prank(user1);
        referralSystem.registerWithReferral("", "USER_CODE");
        
        uint256 activityVolume = 100e18;
        
        // Should not revert but also not distribute rewards
        vm.prank(gameContract);
        referralSystem.recordActivity(user1, ReferralSystem.ActivityType.GamePlay, activityVolume);
        
        // No activity should be recorded since user has no referrer
        assertEq(referralSystem.totalRewardsPaid(), 0);
    }

    function testTierUpgrade() public {
        vm.prank(user1);
        referralSystem.registerWithReferral("", "REFERRER_CODE");
        
        // Manually register enough users to trigger tier upgrade
        for (uint256 i = 0; i < 5; i++) {
            address newUser = address(uint160(0x100 + i));
            string memory newUserCode = string(abi.encodePacked("USER_", vm.toString(i)));
            
            vm.prank(newUser);
            referralSystem.registerWithReferral("REFERRER_CODE", newUserCode);
        }
        
        // Check tier upgrade
        ReferralSystem.ReferralData memory referrerData = referralSystem.getUserReferralData(user1);
        assertEq(referrerData.tierLevel, 1); // Should be Bronze tier now
    }

    function testUpdateReferralCode() public {
        string memory oldCode = "OLD_CODE";
        string memory newCode = "NEW_CODE";
        
        vm.prank(user1);
        referralSystem.registerWithReferral("", oldCode);
        
        vm.expectEmit(true, false, false, true);
        emit ReferralCodeUpdated(user1, oldCode, newCode);
        
        vm.prank(user1);
        referralSystem.updateReferralCode(newCode);
        
        // Check code mappings updated
        assertEq(referralSystem.referralCodes(oldCode), address(0));
        assertEq(referralSystem.referralCodes(newCode), user1);
        assertEq(referralSystem.userReferralCodes(user1), newCode);
    }

    function testUpdateReferralCodeAlreadyExists() public {
        vm.prank(user1);
        referralSystem.registerWithReferral("", "CODE1");
        
        vm.prank(user2);
        referralSystem.registerWithReferral("", "CODE2");
        
        vm.expectRevert(ReferralSystem.CodeAlreadyExists.selector);
        vm.prank(user1);
        referralSystem.updateReferralCode("CODE2");
    }

    function testGetUserPerformance() public {
        vm.prank(user1);
        referralSystem.registerWithReferral("", "REFERRER_CODE");
        
        (
            uint256 totalEarnings,
            uint256 currentTier,
            uint256 nextTierRequirement,
            string memory referralCode
        ) = referralSystem.getUserPerformance(user1);
        
        assertEq(totalEarnings, 0);
        assertEq(currentTier, 0);
        assertEq(nextTierRequirement, 5); // Need 5 referrals for next tier
        assertEq(referralCode, "REFERRER_CODE");
    }

    function testSetActivityRewardRate() public {
        uint256 newRate = 300; // 3%
        
        vm.prank(admin);
        referralSystem.setActivityRewardRate(ReferralSystem.ActivityType.GamePlay, newRate);
        
        assertEq(referralSystem.activityRewardRates(ReferralSystem.ActivityType.GamePlay), newRate);
    }

    function testSetTierMultiplier() public {
        uint256 newMultiplier = 20000; // 2x
        
        vm.prank(admin);
        referralSystem.setTierMultiplier(GamePass.Tier.Gold, newMultiplier);
        
        assertEq(referralSystem.tierMultipliers(GamePass.Tier.Gold), newMultiplier);
    }

    function testSetReferralTier() public {
        uint256 tierLevel = 5;
        uint256 minReferrals = 200;
        uint256 rewardRate = 600;
        uint256 bonusRate = 400;
        string memory name = "Diamond";
        
        vm.prank(admin);
        referralSystem.setReferralTier(tierLevel, minReferrals, rewardRate, bonusRate, name);
        
        (uint256 min, uint256 rate, uint256 bonus, string memory tierName) = referralSystem.referralTiers(tierLevel);
        assertEq(min, minReferrals);
        assertEq(rate, rewardRate);
        assertEq(bonus, bonusRate);
        assertEq(tierName, name);
        assertEq(referralSystem.tierCount(), 6); // Should be updated
    }

    function testSetMinimumActivityVolume() public {
        uint256 newMinVolume = 50e18;
        
        vm.prank(admin);
        referralSystem.setMinimumActivityVolume(newMinVolume);
        
        assertEq(referralSystem.minimumActivityVolume(), newMinVolume);
    }

    function testSetMaxRewardPerActivity() public {
        uint256 newMaxReward = 2000e18;
        
        vm.prank(admin);
        referralSystem.setMaxRewardPerActivity(newMaxReward);
        
        assertEq(referralSystem.maxRewardPerActivity(), newMaxReward);
    }

    function testPauseAndUnpause() public {
        vm.prank(admin);
        referralSystem.pause();
        assertTrue(referralSystem.paused());
        
        vm.expectRevert("Pausable: paused");
        vm.prank(user1);
        referralSystem.registerWithReferral("", "CODE");
        
        vm.prank(admin);
        referralSystem.unpause();
        assertFalse(referralSystem.paused());
        
        // Should work now
        vm.prank(user1);
        referralSystem.registerWithReferral("", "CODE");
    }

    function testEmergencyWithdraw() public {
        uint256 withdrawAmount = 1000e18;
        
        // Fund the treasury with tokens
        vm.prank(admin);
        gameToken.mint(treasury, withdrawAmount * 2);
        
        // Approve the referral system to spend tokens from treasury
        vm.prank(treasury);
        gameToken.approve(address(referralSystem), withdrawAmount * 2);
        
        vm.prank(admin);
        referralSystem.pause();
        
        uint256 balanceBefore = gameToken.balanceOf(admin);
        
        vm.prank(admin);
        referralSystem.emergencyWithdraw(admin, withdrawAmount);
        
        assertEq(gameToken.balanceOf(admin), balanceBefore + withdrawAmount);
        assertEq(gameToken.balanceOf(treasury), withdrawAmount);
    }

    function testAccessControl() public {
        // Non-admin cannot set activity rates
        vm.expectRevert();
        vm.prank(user1);
        referralSystem.setActivityRewardRate(ReferralSystem.ActivityType.GamePlay, 300);
        
        // Non-activity-recorder cannot record activity
        vm.expectRevert();
        vm.prank(user1);
        referralSystem.recordActivity(user2, ReferralSystem.ActivityType.GamePlay, 100e18);
        
        // Non-pauser cannot pause
        vm.expectRevert();
        vm.prank(user1);
        referralSystem.pause();
    }

    // Fuzz tests
    function testFuzzRegisterUser(string calldata userCode) public {
        vm.assume(bytes(userCode).length > 0 && bytes(userCode).length <= 20);
        vm.assume(referralSystem.referralCodes(userCode) == address(0));
        
        vm.prank(user1);
        referralSystem.registerWithReferral("", userCode);
        
        assertEq(referralSystem.referralCodes(userCode), user1);
        assertTrue(referralSystem.getUserReferralData(user1).isActive);
    }

    function testFuzzActivityVolume(uint256 volume) public {
        vm.assume(volume >= 10e18 && volume <= 10000e18);
        
        // Setup referral relationship
        vm.prank(user1);
        referralSystem.registerWithReferral("", "REFERRER");
        
        vm.prank(user2);
        referralSystem.registerWithReferral("REFERRER", "USER");
        
        uint256 balanceBefore = gameToken.balanceOf(user1);
        
        vm.prank(gameContract);
        referralSystem.recordActivity(user2, ReferralSystem.ActivityType.GamePlay, volume);
        
        uint256 balanceAfter = gameToken.balanceOf(user1);
        assertTrue(balanceAfter > balanceBefore); // Should receive some rewards
        
        uint256 expectedMinReward = (volume * 200) / 10000; // At least 2% of volume
        assertTrue(balanceAfter >= balanceBefore + expectedMinReward);
    }
}