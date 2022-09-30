//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC4973} from "../ERC4973/src/ERC4973.sol";
import {IERC4973} from "../ERC4973/src/interfaces/IERC4973.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
@title  Account-based token for the Blue Chip Alliance
@author Marco Huberts
@dev    Implementation of an Account-Bound Token using ERC4973.
*/

contract AccountBoundTokenBca is ERC4973, ReentrancyGuard, AccessControl {
    
    string public baseURI;
    uint256 public MEMBERSHIP_COST = 2.5 ether;
    uint256 public currentTokenId;

    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    
    mapping(address => uint256) public tokenIdsByAddresses;
    mapping(uint => string) public URIS;
    
    event MintCompleted(address receiver, uint256 tokenId, string URI);
    event MemberAdded(address newMember, bytes32 role); 
    event MemberRemoved(address formerMember, uint256 removedTokenId);   

    /**
     * @notice Launches contract, sets bcaCore members as admins and sets base URI.
     * @param _baseURI the base uri where the metadata of the ABT has been stored.
     * @param _bcaCore A list of members of the BCA that will receive the admin role.
     */

    constructor(
        string memory _baseURI,
        address[] memory _bcaCore
    ) ERC4973("BlueChipAlliance", "BCA", "") {
        baseURI = _baseURI;
        for (uint256 i = 0; i < _bcaCore.length; i++) {
            _setupRole(DEFAULT_ADMIN_ROLE, _bcaCore[i]);
        }
        _setRoleAdmin(MEMBER_ROLE, DEFAULT_ADMIN_ROLE);
    }
    
    /**
    *@dev   constructs the URI based on the given token Id
    @param tokenId is the id of the token
    */
    function _URI(uint256 tokenId) public view returns (string memory) {
      return string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
    }

    /**
    *@dev   sets the price for the membership based on the multiplier.
    @param _multiplier is the number that we multipl times 0.5 ether 
            so that the price can be set with half ethers and not whole.
    */
    function setEthPriceForMembership(uint256 _multiplier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MEMBERSHIP_COST = (1 ether / 2) * _multiplier;
    }

    /**
    *@dev   refunds if more ether is send than necessary.
    */
    function refundIfOver() internal {
        require(msg.value >= MEMBERSHIP_COST, "Need to send more ETH");
        if (msg.value > MEMBERSHIP_COST) {
            payable(msg.sender).transfer(msg.value - MEMBERSHIP_COST);
        }
    }

    /**
    *@dev   sends ether stored in the contract to admin.
    */
    function withdrawEther() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success);
    }

    /**
    *@dev   allows members of the BCA to mint an Account-Bound Token.
    */
    function memberMint() external payable onlyRole(MEMBER_ROLE) {
        refundIfOver();
        currentTokenId++;
        tokenIdsByAddresses[msg.sender] = currentTokenId;
        _mint(address(this), msg.sender, currentTokenId, _URI(currentTokenId));
        emit MintCompleted(msg.sender, currentTokenId, _URI(currentTokenId)); 
    }

    /**
    *@dev   admin can give the member role to an address.
    */
    function giveMemberRole(address memberAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setupRole(MEMBER_ROLE, memberAddress);
        emit MemberAdded(memberAddress, MEMBER_ROLE);
    }

    /**
    *@dev   removes a member by burning the token and deleting the entry in the mapping
    *@param formerMemberAddress is the address of the member that needs to be removed
    */
    function removeMember(address formerMemberAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MEMBER_ROLE, formerMemberAddress);
        _burn(tokenIdsByAddresses[formerMemberAddress]);
        delete tokenIdsByAddresses[formerMemberAddress];
        emit MemberRemoved(formerMemberAddress, tokenIdsByAddresses[formerMemberAddress]);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC4973, AccessControl) returns (bool) {
        return interfaceId == type(IERC4973).interfaceId || super.supportsInterface(interfaceId);
    }

    // give, take and unequip functions can only be called by the admins.

    function give(address to, string calldata uri, bytes calldata signature) override public virtual returns (uint256) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "You are not an admin");
        give(to, uri, signature);
    }

    function take(address to, string calldata uri, bytes calldata signature) override public virtual returns (uint256) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "You are not an admin");
        take(to, uri, signature);
    }

    function unequip(uint256 tokenId) public virtual override {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "You are not an admin");
        unequip(tokenId);
    }

}