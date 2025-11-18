// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title GamePass
 * @notice ERC-721 NFT pass with tier-based access system for the GameFi platform
 * @dev Implements Bronze/Silver/Gold tiers with different access levels and benefits
 */
contract GamePass is ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;

    /// @notice Role for minting passes
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Pass tiers
    enum Tier { Bronze, Silver, Gold }

    /// @notice Token counter
    Counters.Counter private _tokenIdCounter;

    /// @notice Base URI for token metadata
    string private _baseTokenURI;

    /// @notice Mapping from token ID to tier
    mapping(uint256 => Tier) public tokenTier;

    /// @notice Mapping from tier to mint price
    mapping(Tier => uint256) public tierPrice;

    /// @notice Mapping from tier to supply cap (0 = unlimited)
    mapping(Tier => uint256) public tierSupplyCap;

    /// @notice Mapping from tier to current supply
    mapping(Tier => uint256) public tierSupply;

    /// @notice Treasury address for mint fees
    address public treasury;

    /// @notice Whether public minting is enabled
    bool public publicMintEnabled;

    /// @notice Events
    event PassMinted(address indexed to, uint256 indexed tokenId, Tier tier);
    event TierPriceUpdated(Tier tier, uint256 newPrice);
    event TierSupplyCapUpdated(Tier tier, uint256 newCap);
    event TreasuryUpdated(address indexed newTreasury);
    event PublicMintToggled(bool enabled);
    event BaseURIUpdated(string newBaseURI);

    /// @notice Custom errors
    error ZeroAddress();
    error InvalidTier();
    error InsufficientPayment();
    error ExceedsTierSupplyCap();
    error PublicMintDisabled();
    error TokenNotExists();

    /**
     * @notice Constructor
     * @param name NFT collection name
     * @param symbol NFT collection symbol
     * @param baseURI Base URI for token metadata
     * @param treasuryAddress Treasury address for fees
     * @param admin Admin address for role management
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        address treasuryAddress,
        address admin
    ) ERC721(name, symbol) {
        if (treasuryAddress == address(0) || admin == address(0)) revert ZeroAddress();

        _baseTokenURI = baseURI;
        treasury = treasuryAddress;

        // Grant roles to admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Set default tier prices (in wei for testnet)
        tierPrice[Tier.Bronze] = 0.001 ether;
        tierPrice[Tier.Silver] = 0.005 ether;
        tierPrice[Tier.Gold] = 0.01 ether;

        // Start token IDs at 1
        _tokenIdCounter.increment();
    }

    /**
     * @notice Public mint function for users to mint passes
     * @param to Recipient address
     * @param tier Tier to mint
     */
    function mintPass(address to, Tier tier) external payable whenNotPaused nonReentrant {
        if (!publicMintEnabled && !hasRole(MINTER_ROLE, msg.sender)) {
            revert PublicMintDisabled();
        }
        if (to == address(0)) revert ZeroAddress();
        if (uint8(tier) > uint8(Tier.Gold)) revert InvalidTier();

        // Check payment
        uint256 price = tierPrice[tier];
        if (msg.value < price) revert InsufficientPayment();

        // Check supply cap
        uint256 cap = tierSupplyCap[tier];
        if (cap > 0 && tierSupply[tier] >= cap) revert ExceedsTierSupplyCap();

        // Mint the pass
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        tokenTier[tokenId] = tier;
        tierSupply[tier]++;

        _safeMint(to, tokenId);

        // Transfer payment to treasury
        if (msg.value > 0) {
            (bool success, ) = treasury.call{value: msg.value}("");
            require(success, "Payment transfer failed");
        }

        emit PassMinted(to, tokenId, tier);
    }

    /**
     * @notice Admin mint function (bypasses payment and supply checks)
     * @param to Recipient address
     * @param tier Tier to mint
     */
    function adminMint(address to, Tier tier) external onlyRole(MINTER_ROLE) whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (uint8(tier) > uint8(Tier.Gold)) revert InvalidTier();

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        tokenTier[tokenId] = tier;
        tierSupply[tier]++;

        _safeMint(to, tokenId);

        emit PassMinted(to, tokenId, tier);
    }

    /**
     * @notice Check if an address owns any pass
     * @param user Address to check
     * @return Whether the address owns any pass
     */
    function hasPass(address user) public view returns (bool) {
        return balanceOf(user) > 0;
    }

    /**
     * @notice Check if an address owns a pass of minimum tier
     * @param user Address to check
     * @param minTier Minimum tier required
     * @return Whether the user has access
     */
    function hasPassOfTier(address user, Tier minTier) public view returns (bool) {
        uint256 balance = balanceOf(user);
        if (balance == 0) return false;

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            if (uint8(tokenTier[tokenId]) >= uint8(minTier)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Get the tier of a specific token
     * @param tokenId Token ID
     * @return Tier of the token
     */
    function tierOf(uint256 tokenId) external view returns (Tier) {
        if (!_exists(tokenId)) revert TokenNotExists();
        return tokenTier[tokenId];
    }

    /**
     * @notice Get the highest tier owned by a user
     * @param user Address to check
     * @return Highest tier owned (returns Bronze if no pass owned)
     */
    function getHighestTier(address user) external view returns (Tier) {
        uint256 balance = balanceOf(user);
        if (balance == 0) return Tier.Bronze;

        Tier highest = Tier.Bronze;
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            Tier tier = tokenTier[tokenId];
            if (uint8(tier) > uint8(highest)) {
                highest = tier;
            }
        }
        return highest;
    }

    /**
     * @notice Set tier price
     * @param tier Tier to update
     * @param price New price in wei
     */
    function setTierPrice(Tier tier, uint256 price) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tierPrice[tier] = price;
        emit TierPriceUpdated(tier, price);
    }

    /**
     * @notice Set tier supply cap
     * @param tier Tier to update
     * @param cap New supply cap (0 for unlimited)
     */
    function setTierSupplyCap(Tier tier, uint256 cap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tierSupplyCap[tier] = cap;
        emit TierSupplyCapUpdated(tier, cap);
    }

    /**
     * @notice Set treasury address
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) revert ZeroAddress();
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @notice Toggle public minting
     * @param enabled Whether public minting is enabled
     */
    function setPublicMintEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        publicMintEnabled = enabled;
        emit PublicMintToggled(enabled);
    }

    /**
     * @notice Set base URI for token metadata
     * @param newBaseURI New base URI
     */
    function setBaseURI(string calldata newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Withdraw contract balance to treasury
     */
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = treasury.call{value: balance}("");
            require(success, "Withdrawal failed");
        }
    }

    /**
     * @notice Get next token ID that will be minted
     * @return Next token ID
     */
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @notice Override _baseURI to return stored base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Override _beforeTokenTransfer to add pause functionality
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    /**
     * @notice Override _burn to handle URI storage
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        // Decrease tier supply when burning
        Tier tier = tokenTier[tokenId];
        if (tierSupply[tier] > 0) {
            tierSupply[tier]--;
        }
        delete tokenTier[tokenId];
    }

    /**
     * @notice Override tokenURI to handle URI storage
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @notice Override supportsInterface for multiple inheritance
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}