// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title GameToken
 * @notice ERC-20 utility token for the GameFi platform
 * @dev Implements minting/burning with role-based access control and emergency pause functionality
 */
contract GameToken is ERC20, ERC20Permit, ERC20Burnable, AccessControl, Pausable, ReentrancyGuard {
    /// @notice Role for minting tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role for pausing the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Maximum total supply (optional cap for tokenomics)
    uint256 public immutable MAX_SUPPLY;

    /// @notice Events
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    /// @notice Custom errors
    error ExceedsMaxSupply();
    error ZeroAmount();
    error ZeroAddress();

    /**
     * @notice Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial token supply
     * @param maxSupply Maximum token supply (0 for no cap)
     * @param treasury Initial recipient of tokens
     * @param admin Admin address for role management
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maxSupply,
        address treasury,
        address admin
    ) ERC20(name, symbol) ERC20Permit(name) {
        if (treasury == address(0) || admin == address(0)) revert ZeroAddress();
        if (initialSupply == 0) revert ZeroAmount();
        if (maxSupply > 0 && initialSupply > maxSupply) revert ExceedsMaxSupply();

        MAX_SUPPLY = maxSupply;

        // Grant roles to admin
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);

        // Mint initial supply to treasury
        _mint(treasury, initialSupply);
        emit Minted(treasury, initialSupply);
    }

    /**
     * @notice Mint tokens to specified address
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        
        // Check max supply if set
        if (MAX_SUPPLY > 0 && totalSupply() + amount > MAX_SUPPLY) {
            revert ExceedsMaxSupply();
        }

        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burn tokens from caller's balance
     * @param amount Amount to burn
     */
    function burn(uint256 amount) public override whenNotPaused nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        super.burn(amount);
        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from specified account (requires approval)
     * @param account Account to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address account, uint256 amount) public override whenNotPaused nonReentrant {
        if (account == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    /**
     * @notice Pause the contract (emergency function)
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
     * @notice Override transfer to add pause functionality
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @notice Check if address has minter role
     * @param account Address to check
     * @return Whether address has minter role
     */
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @notice Check if address has pauser role
     * @param account Address to check
     * @return Whether address has pauser role
     */
    function isPauser(address account) external view returns (bool) {
        return hasRole(PAUSER_ROLE, account);
    }

    /**
     * @notice Get remaining mintable supply
     * @return Remaining supply that can be minted (0 if no cap)
     */
    function getRemainingSupply() external view returns (uint256) {
        if (MAX_SUPPLY == 0) return type(uint256).max;
        return MAX_SUPPLY - totalSupply();
    }

    /**
     * @notice Support interface detection
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}