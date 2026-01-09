// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol"; 
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol"; 
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title GovernanceToken
 * @dev ERC20 governance token with voting capabilities for DAO decisions
 */
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens

    constructor() ERC20("GameFi DAO Token", "GDAO") ERC20Permit("GameFi DAO Token") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        // Initial mint to deployer for distribution
        _mint(msg.sender, 100_000_000 * 10**18); // 100M tokens initial supply
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(account, amount);
    }

    // Required overrides
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}

/**
 * @title GameFiDAO
 * @dev DAO governance contract for treasury management and roadmap decisions
 */
contract GameFiDAO is AccessControl, Pausable, ReentrancyGuard {
    using Address for address;

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed,
        Cancelled
    }

    enum ProposalType {
        Treasury,
        Roadmap,
        Parameter,
        Emergency
    }

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        ProposalType proposalType;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool cancelled;
        bytes executionData;
        address targetContract;
        uint256 value;
    }

    struct VotingConfig {
        uint256 votingDelay;      // Delay before voting starts (in blocks)
        uint256 votingPeriod;     // Voting duration (in blocks)
        uint256 proposalThreshold; // Minimum tokens needed to propose
        uint256 quorumThreshold;   // Minimum votes needed for quorum (percentage)
    }

    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    GovernanceToken public immutable governanceToken;
    
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => mapping(address => uint8)) public votes; // 0=against, 1=for, 2=abstain
    
    VotingConfig public votingConfig;
    address public treasury;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        ProposalType proposalType,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint8 support,
        uint256 weight,
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    event VotingConfigUpdated(
        uint256 votingDelay,
        uint256 votingPeriod,
        uint256 proposalThreshold,
        uint256 quorumThreshold
    );

    modifier onlyToken() {
        require(msg.sender == address(governanceToken), "Only governance token");
        _;
    }

    constructor(
        address _governanceToken,
        address _treasury,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumThreshold
    ) {
        require(_governanceToken != address(0), "Invalid governance token");
        require(_treasury != address(0), "Invalid treasury");

        governanceToken = GovernanceToken(_governanceToken);
        treasury = _treasury;

        votingConfig = VotingConfig({
            votingDelay: _votingDelay,
            votingPeriod: _votingPeriod,
            proposalThreshold: _proposalThreshold,
            quorumThreshold: _quorumThreshold
        });

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PROPOSER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        _grantRole(GUARDIAN_ROLE, msg.sender);
    }

    /**
     * @dev Create a new proposal
     */
    function propose(
        string memory title,
        string memory description,
        ProposalType proposalType,
        address targetContract,
        uint256 value,
        bytes memory executionData
    ) external whenNotPaused returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        
        // Check proposer has minimum tokens
        uint256 proposerVotes = governanceToken.getVotes(msg.sender);
        require(proposerVotes >= votingConfig.proposalThreshold, "Below proposal threshold");

        uint256 proposalId = ++proposalCount;
        uint256 startTime = block.timestamp + votingConfig.votingDelay;
        uint256 endTime = startTime + votingConfig.votingPeriod;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            proposalType: proposalType,
            startTime: startTime,
            endTime: endTime,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            cancelled: false,
            executionData: executionData,
            targetContract: targetContract,
            value: value
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            title,
            proposalType,
            startTime,
            endTime
        );

        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The proposal to vote on
     * @param support 0=against, 1=for, 2=abstain
     * @param reason Reason for the vote
     */
    function castVote(
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) external whenNotPaused {
        require(support <= 2, "Invalid vote type");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.cancelled, "Proposal cancelled");

        uint256 weight = governanceToken.getVotes(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;
        votes[proposalId][msg.sender] = support;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight, reason);
    }

    /**
     * @dev Execute a successful proposal
     */
    function execute(uint256 proposalId) external nonReentrant {
        require(getProposalState(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        // Execute the proposal
        if (proposal.targetContract != address(0)) {
            (bool success, ) = proposal.targetContract.call{value: proposal.value}(proposal.executionData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancel a proposal (only by guardian in emergency)
     */
    function cancel(uint256 proposalId) external onlyRole(GUARDIAN_ROLE) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Already cancelled");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    /**
     * @dev Get the current state of a proposal
     */
    function getProposalState(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.id != 0, "Proposal does not exist");

        if (proposal.cancelled) {
            return ProposalState.Cancelled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp < proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        // Voting ended, check results
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        uint256 quorum = (totalSupply * votingConfig.quorumThreshold) / 100;

        if (totalVotes < quorum || proposal.againstVotes >= proposal.forVotes) {
            return ProposalState.Defeated;
        }

        return ProposalState.Succeeded;
    }

    /**
     * @dev Update voting configuration
     */
    function updateVotingConfig(
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_quorumThreshold <= 100, "Invalid quorum threshold");
        
        votingConfig = VotingConfig({
            votingDelay: _votingDelay,
            votingPeriod: _votingPeriod,
            proposalThreshold: _proposalThreshold,
            quorumThreshold: _quorumThreshold
        });

        emit VotingConfigUpdated(_votingDelay, _votingPeriod, _proposalThreshold, _quorumThreshold);
    }

    /**
     * @dev Update treasury address
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
    }

    /**
     * @dev Get proposal details
     */
    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    /**
     * @dev Get user's vote on a proposal
     */
    function getUserVote(uint256 proposalId, address user) external view returns (bool voted, uint8 support) {
        return (hasVoted[proposalId][user], votes[proposalId][user]);
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(GUARDIAN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause
     */
    function unpause() external onlyRole(GUARDIAN_ROLE) {
        _unpause();
    }

    /**
     * @dev Receive ETH for treasury operations
     */
    receive() external payable {}
}
