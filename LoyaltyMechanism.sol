// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface LoyaltyMechanism {
    function mint(address to, uint amount) external;
    function setTokenForRetailer(address retailer) external;
    function balanceOf(address account, address retailerAddress) external view returns(uint);
    function transferTokens(address from, address to, uint amount, bool isSenderRetailer) external;


    event Mint(address indexed from, uint tokenId, uint amount);
    event Transfer(address indexed from, address indexed to, uint tokenId, uint amount, uint256 timestamp);
}