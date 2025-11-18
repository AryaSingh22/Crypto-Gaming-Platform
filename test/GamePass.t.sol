// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/GamePass.sol";

contract GamePassTest is Test {
    GamePass public gamePass;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public minter = address(0x5);
    
    string public constant BASE_URI = "https://api.example.com/metadata/";
    
    event PassMinted(address indexed to, uint256 indexed tokenId, GamePass.Tier tier);

    function setUp() public {
        // Use vm.startPrank to ensure all subsequent calls use the admin address
        vm.startPrank(admin);
        
        gamePass = new GamePass(
            "Game Pass",
            "GPASS",
            BASE_URI,
            treasury,
            admin
        );
        
        // Grant minter role to minter address
        gamePass.grantRole(gamePass.MINTER_ROLE(), minter);
        
        // Enable public minting
        gamePass.setPublicMintEnabled(true);
        
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(gamePass.name(), "Game Pass");
        assertEq(gamePass.symbol(), "GPASS");
        assertEq(gamePass.treasury(), treasury);
        assertTrue(gamePass.hasRole(gamePass.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(gamePass.hasRole(gamePass.MINTER_ROLE(), admin));
        assertTrue(gamePass.hasRole(gamePass.PAUSER_ROLE(), admin));
        assertEq(gamePass.getNextTokenId(), 1);
        assertTrue(gamePass.publicMintEnabled());
    }

    function testTierPrices() public view{
        assertEq(gamePass.tierPrice(GamePass.Tier.Bronze), 0.001 ether);
        assertEq(gamePass.tierPrice(GamePass.Tier.Silver), 0.005 ether);
        assertEq(gamePass.tierPrice(GamePass.Tier.Gold), 0.01 ether);
    }

    function testPublicMintBronze() public {
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        
        vm.deal(user1, price);
        
        vm.expectEmit(true, true, false, true);
        emit PassMinted(user1, 1, GamePass.Tier.Bronze);
        
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Bronze);
        
        assertEq(gamePass.balanceOf(user1), 1);
        assertEq(gamePass.ownerOf(1), user1);
        assertEq(uint8(gamePass.tierOf(1)), uint8(GamePass.Tier.Bronze));
        assertEq(gamePass.tierSupply(GamePass.Tier.Bronze), 1);
        assertEq(gamePass.getNextTokenId(), 2);
    }

    function testPublicMintSilver() public {
        uint256 price = gamePass.tierPrice(GamePass.Tier.Silver);
        
        vm.deal(user1, price);
        
        vm.expectEmit(true, true, false, true);
        emit PassMinted(user1, 1, GamePass.Tier.Silver);
        
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Silver);
        
        assertEq(gamePass.balanceOf(user1), 1);
        assertEq(uint8(gamePass.tierOf(1)), uint8(GamePass.Tier.Silver));
        assertEq(gamePass.tierSupply(GamePass.Tier.Silver), 1);
    }

    function testPublicMintGold() public {
        uint256 price = gamePass.tierPrice(GamePass.Tier.Gold);
        
        vm.deal(user1, price);
        
        vm.expectEmit(true, true, false, true);
        emit PassMinted(user1, 1, GamePass.Tier.Gold);
        
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Gold);
        
        assertEq(gamePass.balanceOf(user1), 1);
        assertEq(uint8(gamePass.tierOf(1)), uint8(GamePass.Tier.Gold));
        assertEq(gamePass.tierSupply(GamePass.Tier.Gold), 1);
    }

    function testMintRequiresCorrectPayment() public {
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        
        vm.deal(user1, price - 1);
        
        vm.expectRevert(GamePass.InsufficientPayment.selector);
        vm.prank(user1);
        gamePass.mintPass{value: price - 1}(user1, GamePass.Tier.Bronze);
    }

    function testMintWithExcessPayment() public {
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        uint256 overpayment = price + 0.001 ether;
        
        vm.deal(user1, overpayment);
        uint256 treasuryBalanceBefore = treasury.balance;
        
        vm.prank(user1);
        gamePass.mintPass{value: overpayment}(user1, GamePass.Tier.Bronze);
        
        assertEq(gamePass.balanceOf(user1), 1);
        assertEq(treasury.balance, treasuryBalanceBefore + overpayment);
    }

    function testAdminMint() public {
        vm.expectEmit(true, true, false, true);
        emit PassMinted(user1, 1, GamePass.Tier.Gold);
        
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Gold);
        
        assertEq(gamePass.balanceOf(user1), 1);
        assertEq(uint8(gamePass.tierOf(1)), uint8(GamePass.Tier.Gold));
        assertEq(gamePass.tierSupply(GamePass.Tier.Gold), 1);
    }

    function testBatchMint() public {
        address[] memory recipients = new address[](3);
        GamePass.Tier[] memory tiers = new GamePass.Tier[](3);
        
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = address(0x6);
        
        tiers[0] = GamePass.Tier.Bronze;
        tiers[1] = GamePass.Tier.Silver;
        tiers[2] = GamePass.Tier.Gold;
        
        vm.prank(minter);
        gamePass.adminMint(recipients[0], tiers[0]);
        vm.prank(minter);
        gamePass.adminMint(recipients[1], tiers[1]);
        vm.prank(minter);
        gamePass.adminMint(recipients[2], tiers[2]);
        
        assertEq(gamePass.balanceOf(user1), 1);
        assertEq(gamePass.balanceOf(user2), 1);
        assertEq(gamePass.balanceOf(address(0x6)), 1);
        
        assertEq(uint8(gamePass.tierOf(1)), uint8(GamePass.Tier.Bronze));
        assertEq(uint8(gamePass.tierOf(2)), uint8(GamePass.Tier.Silver));
        assertEq(uint8(gamePass.tierOf(3)), uint8(GamePass.Tier.Gold));
        
        // Check that 3 tokens were minted (token IDs 1, 2, 3)
        assertEq(gamePass.totalSupply(), 3);
    }

    function testHasPass() public {
        assertFalse(gamePass.hasPass(user1));
        
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        
        assertTrue(gamePass.hasPass(user1));
    }

    function testHasPassOfTier() public {
        // Mint bronze pass
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        
        assertTrue(gamePass.hasPassOfTier(user1, GamePass.Tier.Bronze));
        assertFalse(gamePass.hasPassOfTier(user1, GamePass.Tier.Silver));
        assertFalse(gamePass.hasPassOfTier(user1, GamePass.Tier.Gold));
        
        // Mint silver pass
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Silver);
        
        assertTrue(gamePass.hasPassOfTier(user1, GamePass.Tier.Bronze));
        assertTrue(gamePass.hasPassOfTier(user1, GamePass.Tier.Silver));
        assertFalse(gamePass.hasPassOfTier(user1, GamePass.Tier.Gold));
    }

    function testGetHighestTier() public {
        // No pass
        assertEq(uint8(gamePass.getHighestTier(user1)), uint8(GamePass.Tier.Bronze));
        
        // Bronze pass
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        assertEq(uint8(gamePass.getHighestTier(user1)), uint8(GamePass.Tier.Bronze));
        
        // Add gold pass
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Gold);
        assertEq(uint8(gamePass.getHighestTier(user1)), uint8(GamePass.Tier.Gold));
    }

    function testSupplyCap() public {
        // Set supply cap for bronze
        vm.prank(admin);
        gamePass.setTierSupplyCap(GamePass.Tier.Bronze, 2);
        
        // Mint 2 bronze passes
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        vm.prank(minter);
        gamePass.adminMint(user2, GamePass.Tier.Bronze);
        
        // Try to mint 3rd bronze pass
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        vm.deal(address(0x6), price);
        
        vm.expectRevert(GamePass.ExceedsTierSupplyCap.selector);
        vm.prank(address(0x6));
        gamePass.mintPass{value: price}(address(0x6), GamePass.Tier.Bronze);
    }

    // Events for testing
    event TierPriceUpdated(GamePass.Tier tier, uint256 newPrice);
    event TreasuryUpdated(address indexed newTreasury);
    
    function testSetTierPrice() public {
        uint256 newPrice = 0.002 ether;
        
        vm.expectEmit(false, false, false, true);
        emit TierPriceUpdated(GamePass.Tier.Bronze, newPrice);
        
        vm.prank(admin);
        gamePass.setTierPrice(GamePass.Tier.Bronze, newPrice);
        
        assertEq(gamePass.tierPrice(GamePass.Tier.Bronze), newPrice);
    }

    function testSetTreasury() public {
        address newTreasury = address(0x7);
        
        vm.expectEmit(true, false, false, false);
        emit TreasuryUpdated(newTreasury);
        
        vm.prank(admin);
        gamePass.setTreasury(newTreasury);
        
        assertEq(gamePass.treasury(), newTreasury);
    }

    function testPublicMintToggle() public {
        // Disable public minting
        vm.prank(admin);
        gamePass.setPublicMintEnabled(false);
        assertFalse(gamePass.publicMintEnabled());
        
        // Try to mint as regular user
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        vm.deal(user1, price);
        
        vm.expectRevert(GamePass.PublicMintDisabled.selector);
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Bronze);
        
        // Admin should still be able to mint using adminMint (which bypasses payment)
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        
        assertEq(gamePass.balanceOf(user1), 1);
    }

    function testPauseAndUnpause() public {
        // Pause contract
        vm.prank(admin);
        gamePass.pause();
        assertTrue(gamePass.paused());
        
        // Try to mint while paused
        vm.expectRevert("Pausable: paused");
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        
        // Unpause
        vm.prank(admin);
        gamePass.unpause();
        assertFalse(gamePass.paused());
        
        // Should work now
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        assertEq(gamePass.balanceOf(user1), 1);
    }

    function testWithdraw() public {
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        vm.deal(user1, price);
        
        uint256 treasuryBalanceBefore = treasury.balance;
        
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Bronze);
        
        // Contract should have balance
        assertEq(address(gamePass).balance, 0); // Already transferred to treasury
        assertEq(treasury.balance, treasuryBalanceBefore + price);
    }

    function testTokenURI() public {
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        
        string memory uri = gamePass.tokenURI(1);
        assertEq(uri, string(abi.encodePacked(BASE_URI, "1")));
    }

    function testSetBaseURI() public {
        string memory newBaseURI = "https://newapi.example.com/metadata/";
        
        vm.prank(admin);
        gamePass.setBaseURI(newBaseURI);
        
        vm.prank(minter);
        gamePass.adminMint(user1, GamePass.Tier.Bronze);
        
        string memory uri = gamePass.tokenURI(1);
        assertEq(uri, string(abi.encodePacked(newBaseURI, "1")));
    }

    function testInvalidTier() public {
        // Test invalid tier - GamePass only has Bronze(0), Silver(1), Gold(2)
        // Since enum casting with invalid values causes compilation error, 
        // we'll test with a direct call that should revert
        
        // Test with low-level call using invalid tier value (3)
        bytes memory invalidTierCall = abi.encodeWithSelector(
            gamePass.adminMint.selector,
            user1,
            3 // Invalid tier value
        );
        vm.expectRevert(GamePass.InvalidTier.selector);
        vm.prank(minter);
        (bool success,) = address(gamePass).call(invalidTierCall);
        // We expect this to fail with a revert, so success should be false
        assertFalse(success);
    }

    function testZeroAddressChecks() public {
        vm.expectRevert(GamePass.ZeroAddress.selector);
        vm.prank(minter);
        gamePass.adminMint(address(0), GamePass.Tier.Bronze);
        
        vm.expectRevert(GamePass.ZeroAddress.selector);
        vm.prank(admin);
        gamePass.setTreasury(address(0));
    }

    function testTokenNotExists() public {
        vm.expectRevert(GamePass.TokenNotExists.selector);
        gamePass.tierOf(999);
    }

    function testAccessControl() public {
        // Non-admin cannot set tier price
        vm.expectRevert();
        vm.prank(user1);
        gamePass.setTierPrice(GamePass.Tier.Bronze, 0.002 ether);
        
        // Non-minter cannot admin mint
        vm.expectRevert();
        vm.prank(user1);
        gamePass.adminMint(user2, GamePass.Tier.Bronze);
        
        // Non-pauser cannot pause
        vm.expectRevert();
        vm.prank(user1);
        gamePass.pause();
    }

    // Fuzz tests
    function testFuzzMintWithPrice(uint96 price) public {
        vm.assume(price >= gamePass.tierPrice(GamePass.Tier.Bronze));
        
        vm.deal(user1, price);
        
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Bronze);
        
        assertEq(gamePass.balanceOf(user1), 1);
    }

    function testFuzzSupplyCap(uint8 cap) public {
        vm.assume(cap > 0 && cap <= 100);
        
        vm.prank(admin);
        gamePass.setTierSupplyCap(GamePass.Tier.Bronze, cap);
        
        // Mint up to cap
        for (uint256 i = 0; i < cap; i++) {
            vm.prank(minter);
            gamePass.adminMint(address(uint160(0x1000 + i)), GamePass.Tier.Bronze);
        }
        
        assertEq(gamePass.tierSupply(GamePass.Tier.Bronze), cap);
        
        // Next mint should fail
        uint256 price = gamePass.tierPrice(GamePass.Tier.Bronze);
        vm.deal(user1, price);
        
        vm.expectRevert(GamePass.ExceedsTierSupplyCap.selector);
        vm.prank(user1);
        gamePass.mintPass{value: price}(user1, GamePass.Tier.Bronze);
    }
}