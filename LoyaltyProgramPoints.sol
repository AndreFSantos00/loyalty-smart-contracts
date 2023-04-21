// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../contracts/LoyaltyMechanism.sol";


contract LoyaltyProgramPoints is ERC1155, LoyaltyMechanism {
    
    uint tokenIDIncrementor;
    mapping (address => uint) tokenOwners;

    constructor() ERC1155("") {
        tokenIDIncrementor = 0;
    }

    function setTokenForRetailer(address retailer) external{
        uint tokenId = getRetailerTokenId(retailer);
        if (tokenId == 0) {
            tokenIDIncrementor = tokenIDIncrementor + 1;
            tokenOwners[retailer] = tokenIDIncrementor;
        }
    }

    function getRetailerTokenId(address user) private view returns(uint tokenId) {
        tokenId = tokenOwners[user];
    }

    function ownerOf(uint256 tokenId, address user) internal view returns (bool) {
        //verify if the user is owner
        if (tokenOwners[user] == tokenId)
            return true;
        else
            return false;
    }
    
    function mint(address to, uint amount) external {
        uint tokenId = getRetailerTokenId(to);
        require(ownerOf(tokenId, to), string.concat("Not the owner of the Token", Strings.toString(tokenId)));
        _mint(to, tokenId, amount, "");

        emit Mint(to, tokenId, amount);
    }

    function balanceOf(address account, address retailerAddress) external view returns(uint) {
        uint tokenId = getRetailerTokenId(retailerAddress);
        return balanceOf(account, tokenId);
    }

    function transferTokens(address from, address to, uint amount, bool isSenderRetailer) external {
        uint tokenId;
        if (isSenderRetailer)
            tokenId = getRetailerTokenId(from);
        else
            tokenId = getRetailerTokenId(to);

        _safeTransferFrom(from, to, tokenId, amount, "");  

        emit Transfer(from, to, tokenId, amount, block.timestamp);
    }
}