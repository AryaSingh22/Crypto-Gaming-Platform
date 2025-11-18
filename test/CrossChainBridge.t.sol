// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/bridge/CrossChainBridge.sol";
import "../src/GameToken.sol";
import "../src/GamePass.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CrossChainBridgeTest is Test {
    using ECDSA for bytes32;

    CrossChainBridge public bridge;
    GameToken public gameToken;
    GamePass public gamePass;

    address public admin = address(0x1);
    address public validator = address(0x2);
    address public user = address(0x3);
    uint256 public validatorPrivateKey = 0x2;

    uint256 public constant POLYGON_CHAIN_ID = 137;
    uint256 public constant BRIDGE_FEE = 0.001 ether;

    event BridgeRequestCreated(
        bytes32 indexed requestHash,
        address indexed user,
        address indexed tokenContract,
        uint256 tokenId,
        uint256 targetChainId,
        bool isNFT,
        uint256 amount
    );

    event BridgeRequestProcessed(
        bytes32 indexed requestHash,
        address indexed user,
        uint256 targetChainId
    );

    function setUp() public {
        vm.startPrank(admin);

        // Deploy tokens
        gameToken = new GameToken("Game Token", "GAME", 1_000_000e18, 0, admin, admin);
        gamePass = new GamePass("Game Pass", "GPASS", "uri", admin, admin);

        // Deploy Bridge
        bridge = new CrossChainBridge();
        
        // Setup roles
        bridge.grantRole(bridge.VALIDATOR_ROLE(), validator);
        
        // Enable public minting for GamePass for testing
        gamePass.setPublicMintEnabled(true);

        vm.stopPrank();

        // Fund user
        vm.deal(user, 10 ether);
        vm.prank(admin);
        gameToken.mint(user, 1000e18);
        vm.prank(user);
        gamePass.mint{value: 0.01 ether}();
    }

    function testInitialState() public view {
        assertTrue(bridge.hasRole(bridge.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(bridge.hasRole(bridge.VALIDATOR_ROLE(), validator));
        
        (bool isActive, uint256 minValidators, uint256 bridgeFee, ) = bridge.chainConfigs(POLYGON_CHAIN_ID);
        assertTrue(isActive);
        assertEq(minValidators, 3);
        assertEq(bridgeFee, 0.001 ether);
    }

    function testBridgeToken() public {
        uint256 amount = 100e18;
        
        vm.startPrank(user);
        gameToken.approve(address(bridge), amount);
        
        vm.expectEmit(true, true, false, true);
        emit BridgeRequestCreated(
            keccak256(abi.encodePacked(user, address(gameToken), uint256(0), POLYGON_CHAIN_ID, uint256(0), block.chainid, false, amount)),
            user,
            address(gameToken),
            0,
            POLYGON_CHAIN_ID,
            false,
            amount
        );

        bridge.bridgeToken{value: BRIDGE_FEE}(
            address(gameToken),
            amount,
            POLYGON_CHAIN_ID
        );
        
        vm.stopPrank();
        
        assertEq(gameToken.balanceOf(address(bridge)), amount);
    }

    function testBridgeNFT() public {
        uint256 tokenId = 1;
        
        vm.startPrank(user);
        gamePass.approve(address(bridge), tokenId);
        
        vm.expectEmit(true, true, false, true);
        emit BridgeRequestCreated(
            keccak256(abi.encodePacked(user, address(gamePass), tokenId, POLYGON_CHAIN_ID, uint256(0), block.chainid, true)),
            user,
            address(gamePass),
            tokenId,
            POLYGON_CHAIN_ID,
            true,
            0
        );

        bridge.bridgeNFT{value: BRIDGE_FEE}(
            address(gamePass),
            tokenId,
            POLYGON_CHAIN_ID
        );
        
        vm.stopPrank();
        
        assertEq(gamePass.ownerOf(tokenId), address(bridge));
    }

    function testSignBridgeRequest() public {
        // Create request first
        uint256 amount = 100e18;
        vm.startPrank(user);
        gameToken.approve(address(bridge), amount);
        bridge.bridgeToken{value: BRIDGE_FEE}(
            address(gameToken),
            amount,
            POLYGON_CHAIN_ID
        );
        vm.stopPrank();

        // Get request hash
        // Nonce is 0 for first request
        bytes32 requestHash = keccak256(abi.encodePacked(
            user,
            address(gameToken),
            uint256(0),
            POLYGON_CHAIN_ID,
            uint256(0),
            block.chainid,
            false,
            amount
        ));

        // Sign request
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            requestHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(validator);
        bridge.signBridgeRequest(requestHash, signature);
        
        assertTrue(bridge.hasValidatorSigned(requestHash, validator));
        assertEq(bridge.getSignatureCount(requestHash), 1);
    }

    function testReleaseBridgedAsset() public {
        uint256 amount = 100e18;
        
        // Fund bridge with tokens (simulate tokens locked from other users)
        vm.prank(admin);
        gameToken.mint(address(bridge), amount);
        
        vm.prank(validator);
        bridge.releaseBridgedAsset(
            user,
            address(gameToken),
            0,
            false,
            amount,
            bytes32(0)
        );
        
        assertEq(gameToken.balanceOf(user), 1000e18 + amount); // Initial 1000 + released 100
    }
}
