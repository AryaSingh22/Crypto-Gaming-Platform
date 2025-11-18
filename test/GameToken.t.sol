// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/GameToken.sol";

contract GameTokenTest is Test {
    GameToken public gameToken;
    
    address public admin = address(0x1);
    address public treasury = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public minter = address(0x5);
    
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
    uint256 public constant MAX_SUPPLY = 10_000_000e18;
    
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    function setUp() public {
        // Use vm.startPrank to ensure all subsequent calls use the admin address
        vm.startPrank(admin);
        
        gameToken = new GameToken(
            "Game Token",
            "GAME",
            INITIAL_SUPPLY,
            MAX_SUPPLY,
            treasury,
            admin
        );
        
        // Grant minter role to minter address
        gameToken.grantRole(gameToken.MINTER_ROLE(), minter);
        
        vm.stopPrank();
    }

    function testInitialState() public view {
        assertEq(gameToken.name(), "Game Token");
        assertEq(gameToken.symbol(), "GAME");
        assertEq(gameToken.decimals(), 18);
        assertEq(gameToken.totalSupply(), INITIAL_SUPPLY);
        assertEq(gameToken.balanceOf(treasury), INITIAL_SUPPLY);
        assertEq(gameToken.MAX_SUPPLY(), MAX_SUPPLY);
        assertTrue(gameToken.hasRole(gameToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(gameToken.hasRole(gameToken.MINTER_ROLE(), admin));
        assertTrue(gameToken.hasRole(gameToken.PAUSER_ROLE(), admin));
    }

    function testMinting() public {
        uint256 mintAmount = 1000e18;
        
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, mintAmount);
        
        vm.prank(minter);
        gameToken.mint(user1, mintAmount);
        
        assertEq(gameToken.balanceOf(user1), mintAmount);
        assertEq(gameToken.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function testMintingRequiresMinterRole() public {
        uint256 mintAmount = 1000e18;
        
        vm.expectRevert();
        vm.prank(user1);
        gameToken.mint(user1, mintAmount);
    }

    function testMintingRespectMaxSupply() public {
        uint256 maxMintAmount = MAX_SUPPLY - INITIAL_SUPPLY + 1;
        
        vm.expectRevert(GameToken.ExceedsMaxSupply.selector);
        vm.prank(minter);
        gameToken.mint(user1, maxMintAmount);
    }

    function testMintingZeroAmount() public {
        vm.expectRevert(GameToken.ZeroAmount.selector);
        vm.prank(minter);
        gameToken.mint(user1, 0);
    }

    function testMintingToZeroAddress() public {
        vm.expectRevert(GameToken.ZeroAddress.selector);
        vm.prank(minter);
        gameToken.mint(address(0), 1000e18);
    }

    function testBurning() public {
        uint256 burnAmount = 1000e18;
        
        // First give user1 some tokens
        vm.prank(minter);
        gameToken.mint(user1, burnAmount);
        
        vm.expectEmit(true, false, false, true);
        emit Burned(user1, burnAmount);
        
        vm.prank(user1);
        gameToken.burn(burnAmount);
        
        assertEq(gameToken.balanceOf(user1), 0);
        assertEq(gameToken.totalSupply(), INITIAL_SUPPLY);
    }

    function testBurnFrom() public {
        uint256 burnAmount = 1000e18;
        
        // First give user1 some tokens
        vm.prank(minter);
        gameToken.mint(user1, burnAmount);
        
        // User1 approves user2 to burn tokens
        vm.prank(user1);
        gameToken.approve(user2, burnAmount);
        
        vm.expectEmit(true, false, false, true);
        emit Burned(user1, burnAmount);
        
        vm.prank(user2);
        gameToken.burnFrom(user1, burnAmount);
        
        assertEq(gameToken.balanceOf(user1), 0);
        assertEq(gameToken.totalSupply(), INITIAL_SUPPLY);
    }

    function testPauseAndUnpause() public {
        // Pause contract
        vm.prank(admin);
        gameToken.pause();
        assertTrue(gameToken.paused());
        
        // Try to mint while paused
        vm.expectRevert("Pausable: paused");
        vm.prank(minter);
        gameToken.mint(user1, 1000e18);
        
        // Try to transfer while paused
        vm.expectRevert("Pausable: paused");
        vm.prank(treasury);
        gameToken.transfer(user1, 1000e18);
        
        // Unpause contract
        vm.prank(admin);
        gameToken.unpause();
        assertFalse(gameToken.paused());
        
        // Should work now
        vm.prank(minter);
        gameToken.mint(user1, 1000e18);
        assertEq(gameToken.balanceOf(user1), 1000e18);
    }

    function testPauseRequiresPauserRole() public {
        vm.expectRevert();
        vm.prank(user1);
        gameToken.pause();
    }

    function testRemainingSupply() public {
        uint256 expected = MAX_SUPPLY - INITIAL_SUPPLY;
        assertEq(gameToken.getRemainingSupply(), expected);
        
        // Mint some tokens
        uint256 mintAmount = 1000e18;
        vm.prank(minter);
        gameToken.mint(user1, mintAmount);
        
        assertEq(gameToken.getRemainingSupply(), expected - mintAmount);
    }

    function testRoleCheckers() public view {
        assertTrue(gameToken.isMinter(admin));
        assertTrue(gameToken.isMinter(minter));
        assertFalse(gameToken.isMinter(user1));
        
        assertTrue(gameToken.isPauser(admin));
        assertFalse(gameToken.isPauser(user1));
    }

    function testConstructorWithZeroAddresses() public {
        vm.expectRevert(GameToken.ZeroAddress.selector);
        new GameToken("Game Token", "GAME", INITIAL_SUPPLY, MAX_SUPPLY, address(0), admin);
        
        vm.expectRevert(GameToken.ZeroAddress.selector);
        new GameToken("Game Token", "GAME", INITIAL_SUPPLY, MAX_SUPPLY, treasury, address(0));
    }

    function testConstructorWithZeroInitialSupply() public {
        vm.expectRevert(GameToken.ZeroAmount.selector);
        new GameToken("Game Token", "GAME", 0, MAX_SUPPLY, treasury, admin);
    }

    function testConstructorWithInvalidMaxSupply() public {
        vm.expectRevert(GameToken.ExceedsMaxSupply.selector);
        new GameToken("Game Token", "GAME", MAX_SUPPLY + 1, MAX_SUPPLY, treasury, admin);
    }

    function testPermit() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);
        
        // Mint tokens to owner
        vm.prank(minter);
        gameToken.mint(owner, 1000e18);
        
        uint256 value = 100e18;
        uint256 nonce = gameToken.nonces(owner);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                gameToken.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                    owner,
                    user1,
                    value,
                    nonce,
                    deadline
                ))
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        gameToken.permit(owner, user1, value, deadline, v, r, s);
        
        assertEq(gameToken.allowance(owner, user1), value);
        assertEq(gameToken.nonces(owner), nonce + 1);
    }

    // Fuzz tests
    function testFuzzMinting(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MAX_SUPPLY - INITIAL_SUPPLY);
        
        vm.prank(minter);
        gameToken.mint(user1, amount);
        
        assertEq(gameToken.balanceOf(user1), amount);
        assertEq(gameToken.totalSupply(), INITIAL_SUPPLY + amount);
    }

    function testFuzzBurning(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= MAX_SUPPLY - INITIAL_SUPPLY);
        vm.assume(burnAmount <= mintAmount);
        
        vm.prank(minter);
        gameToken.mint(user1, mintAmount);
        
        vm.prank(user1);
        gameToken.burn(burnAmount);
        
        assertEq(gameToken.balanceOf(user1), mintAmount - burnAmount);
        assertEq(gameToken.totalSupply(), INITIAL_SUPPLY + mintAmount - burnAmount);
    }
}