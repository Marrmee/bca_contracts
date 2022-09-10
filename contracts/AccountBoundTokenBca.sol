//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {ERC4973} from "../ERC4973/src/ERC4973.sol";
import {IERC4973} from "../ERC4973/src/interfaces/IERC4973.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
@title  Account-based token for the Blue Chip Alliance
@author Marco Huberts
@dev    Implementation of an Account-Based Token using ERC4973.
*/

contract AccountBoundTokenBca is ERC4973, ReentrancyGuard, AccessControl {
    
    string public baseURI;
    uint256 public MEMBERSHIP_COST = 2.5 ether;
    uint256 public currentTokenId;

    bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
    
    mapping(address => uint256) public tokenIdsByAddresses;
    mapping(uint => string) public URIS;
    
    event mintCompleted(address receiver, uint256 tokenId, string URI);
    event memberAdded(address newMember, bytes32 role); 
    event memberRemoved(address formerMember, uint256 burnedTokenId);   

    constructor(
        string memory baseURI_,
        address[] memory _bcaCore
    ) ERC4973("BlueChipAlliance", "BCA", "")
    {
        baseURI = baseURI_;

        for (uint256 i = 0; i < _bcaCore.length; i++) {
            _setupRole(DEFAULT_ADMIN_ROLE, _bcaCore[i]);
        }
        _setRoleAdmin(MEMBER_ROLE, DEFAULT_ADMIN_ROLE);
    }
    
    function _URI(uint256 tokenId) public view returns (string memory) {
      if(bytes(URIS[tokenId]).length != 0) {
        return string(URIS[tokenId]);
      }
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
        emit mintCompleted(msg.sender, currentTokenId, _URI(currentTokenId)); 
    }

    /**
    *@dev   admin can give the member role to an address.
    */
    function giveMemberRole(address memberAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setupRole(MEMBER_ROLE, memberAddress);
        emit memberAdded(memberAddress, MEMBER_ROLE);
    }

    function removeMember(address formerMemberAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MEMBER_ROLE, formerMemberAddress);
        _burn(tokenIdsByAddresses[formerMemberAddress]);
        delete tokenIdsByAddresses[formerMemberAddress];
        emit memberRemoved(formerMemberAddress, tokenIdsByAddresses[formerMemberAddress]);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC4973, AccessControl) returns (bool) {
        return interfaceId == type(ERC4973).interfaceId || super.supportsInterface(interfaceId);
    }

    function give(address to, string calldata uri, bytes calldata signature) override public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        give(to, uri, signature);
    }

    function take(address to, string calldata uri, bytes calldata signature) override public virtual onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        take(to, uri, signature);
    }

    function unequip(uint256 tokenId) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        unequip(tokenId);
    }

}