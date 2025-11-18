// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/governance/GameFiDAO.sol";

contract GameFiDAOTest is Test {
    GameFiDAO public dao;
    GovernanceToken public token;
    
    address public admin = address(0x1);
    address public proposer = address(0x2);
    address public voter1 = address(0x3);
    address public voter2 = address(0x4);
    address public treasury = address(0x5);

    uint256 public constant VOTING_DELAY = 1; // 1 block
    uint256 public constant VOTING_PERIOD = 10; // 10 blocks
    uint256 public constant PROPOSAL_THRESHOLD = 100_000e18;
    uint256 public constant QUORUM_THRESHOLD = 4; // 4%

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy Token
        token = new GovernanceToken();
        
        // Deploy DAO
        dao = new GameFiDAO(
            address(token),
            treasury,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_THRESHOLD
        );
        
        // Grant minter role to admin for setup
        token.grantRole(token.MINTER_ROLE(), admin);
        
        // Distribute tokens
        token.mint(proposer, PROPOSAL_THRESHOLD);
        token.mint(voter1, 1_000_000e18);
        token.mint(voter2, 1_000_000e18);
        
        vm.stopPrank();
        
        // Delegate votes to self
        vm.prank(proposer);
        token.delegate(proposer);
        
        vm.prank(voter1);
        token.delegate(voter1);
        
        vm.prank(voter2);
        token.delegate(voter2);
    }

    function testPropose() public {
        vm.prank(proposer);
        uint256 proposalId = dao.propose(
            "Test Proposal",
            "Description",
            GameFiDAO.ProposalType.Treasury,
            address(0),
            0,
            ""
        );
        
        assertEq(proposalId, 1);
        assertEq(uint(dao.getProposalState(proposalId)), uint(GameFiDAO.ProposalState.Pending));
    }

    function testVote() public {
        vm.prank(proposer);
        uint256 proposalId = dao.propose(
            "Test Proposal",
            "Description",
            GameFiDAO.ProposalType.Treasury,
            address(0),
            0,
            ""
        );
        
        // Advance to active state
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.warp(block.timestamp + VOTING_DELAY * 12 + 1); // Approximate time
        
        vm.prank(voter1);
        dao.castVote(proposalId, 1, "Support"); // 1 = For
        
        (bool voted, uint8 support) = dao.getUserVote(proposalId, voter1);
        assertTrue(voted);
        assertEq(support, 1);
    }

    function testExecute() public {
        vm.prank(proposer);
        uint256 proposalId = dao.propose(
            "Test Proposal",
            "Description",
            GameFiDAO.ProposalType.Treasury,
            address(0),
            0,
            ""
        );
        
        vm.roll(block.number + VOTING_DELAY + 1);
        
        vm.prank(voter1);
        dao.castVote(proposalId, 1, "Support");
        
        // Advance to end of voting period
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        assertEq(uint(dao.getProposalState(proposalId)), uint(GameFiDAO.ProposalState.Succeeded));
        
        dao.execute(proposalId);
        assertEq(uint(dao.getProposalState(proposalId)), uint(GameFiDAO.ProposalState.Executed));
    }
}
