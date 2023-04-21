// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/metatx/MinimalForwarder.sol";

import "../contracts/LoyaltyProgramPoints.sol";
import "../contracts/LoyaltyMechanism.sol";


contract LoyaltyManager is ERC2771Context { // Initializable (add when change to upgradable)

    uint retailersRegisterdCounter;

    //adress = retailer address
    mapping (address => uint) retailersKey;
    //uint reatailer Key
    mapping (uint => RetailerInfo) registeredRetailers;

    //adress = customer address
    mapping (address => RetailerInfo[]) customersSubscriptions;

    mapping (LoyaltyMechanismType => LoyaltyMechanism) loyaltyMechanismContracts;

    enum LoyaltyMechanismType {POINTS, STAMP_CARDS}

    struct RetailerInfo {
        address retailerAddress;
        string ipfsHash;
        LoyaltyMechanismType loyaltyMechanismType;
    }

    /*
    ****EVENTS*****
    */
    event NewRetailer(address indexed retailerAddress, string ipfsHash, uint loyaltyType);

    // /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(MinimalForwarder forwarder, LoyaltyProgramPoints loyaltyProgramPoints) // Initialize trusted forwarder
        ERC2771Context(address(forwarder)) 
    {
        retailersRegisterdCounter = 0;
        loyaltyMechanismContracts[LoyaltyMechanismType.POINTS] = loyaltyProgramPoints;
    }
    
    /* function initialize(uint num) public initializer {
        num++;
    } */

    function addRetailersRegistry(string memory ipfsHash, LoyaltyMechanismType loyaltyType) public {
        address user = _msgSender();
        if ( retailersKey[user] == 0 ) {
            retailersRegisterdCounter++;
            retailersKey[user] = retailersRegisterdCounter;
            registeredRetailers[retailersRegisterdCounter] = RetailerInfo(user, ipfsHash, loyaltyType);
        
            loyaltyMechanismContracts[loyaltyType].setTokenForRetailer(user);
            
            emit NewRetailer(user, ipfsHash, uint(loyaltyType));
        }
        else {
            revert ("Retailer already registered");
        }
    }

    function getRetailerInfo(address retailerAddress) public view returns(RetailerInfo memory) {
        uint retailerKey = retailersKey[retailerAddress];
        require(retailerKey != 0, "This address doesn't belong to a retailer");
        return registeredRetailers[retailerKey];
    }

    function getLoyaltyMechanismType(address retailerAddress) internal view returns(LoyaltyMechanismType) {
        RetailerInfo memory info = this.getRetailerInfo(retailerAddress);
        return info.loyaltyMechanismType;
    }

    function retrieveAllRetailersRegistry() public view returns(RetailerInfo[] memory) {
        RetailerInfo[] memory retailersSubscribedArray = retrieveCustomerSubscriptions();
        uint numberOfRetailers = retailersRegisterdCounter - retailersSubscribedArray.length;
        RetailerInfo[] memory retailersArray = new RetailerInfo[](numberOfRetailers);

        uint counter = 0;
        for (uint i = 0;  i < retailersRegisterdCounter; i++) {
            bool subscribed = false;
            for (uint j = 0; j < retailersSubscribedArray.length; j++) {
                if (retailersSubscribedArray[j].retailerAddress == registeredRetailers[i + 1].retailerAddress) {
                    subscribed = true;
                    break;
                }
            }
            if (!subscribed) {
                retailersArray[counter] = registeredRetailers[i + 1];
                counter = counter + 1;
            }
        }
        return retailersArray;
    }


    function addCustomerSubscription(address retailerToSusbcribe) public {
        RetailerInfo[] memory retailersSubscribedArray = customersSubscriptions[_msgSender()];

        for (uint i = 0; i < retailersSubscribedArray.length; i++) {  
            require(retailersSubscribedArray[i].retailerAddress != retailerToSusbcribe, "Already subscribed");
        }

        customersSubscriptions[_msgSender()].push(getRetailerInfo(retailerToSusbcribe));
    }

    function retrieveCustomerSubscriptions() public view returns(RetailerInfo[] memory) {
        return customersSubscriptions[_msgSender()];
    }

    function checkIfAddressIsRetailer(address addressToCheck) internal view returns(bool){
        uint retailerKey = retailersKey[addressToCheck];
        if (retailerKey != 0)
            return true;
        else
            return false;    
    }

    function checkIfCustomerIsSubscribedToRetailer(address retailer, address customer) internal view returns(bool){
        RetailerInfo[] memory retailersSubscribed = customersSubscriptions[customer];
        bool isSubscribed = false;

        for (uint i = 0; i < retailersSubscribed.length; i++) {
            if (retailersSubscribed[i].retailerAddress == retailer) {
                isSubscribed = true;
                break;
            }
        }

        return isSubscribed;
    }

    /**
    * Mint Retilaers token  
    *
    * - 'amount' amount of tokens to create
    *
    * This funtion only works if the caller is a retailer
    *
    * First obtains the retailer loyalty mechanism to call the correct contract
    * At same time verifies if the caller is a retailer; If not the transaction is reverted
    * Makes a call to the contract mint function and passes the sender and amount as arguments
    * The sender must be a Retailer 
    */
    function mintRetailersToken(uint amount) external {
        LoyaltyMechanismType loyaltyMechanismType = getLoyaltyMechanismType(_msgSender());
        loyaltyMechanismContracts[loyaltyMechanismType].mint(_msgSender(), amount);
    }

    /**
    * Check balance 
    *
    * - 'retailerAddress' is needed to check in which contract is the information
    *
    * First checks which contract is stored based on loyalty mechanism
    * Makes a call to the contract balanceOf function and passes the sender of the order as an argument
    * The sender can be a Retailer or Customer
    */
    function userBalanceOf(address retailerAddress) external view returns(uint){
        LoyaltyMechanismType loyaltyMechanismType = getLoyaltyMechanismType(retailerAddress);
        return loyaltyMechanismContracts[loyaltyMechanismType].balanceOf(_msgSender(), retailerAddress);
    }

    /**
    * Transfer tokens 
    *
    *  - 'to' address of the receiver of the tokens
    *  - 'amount' amount of tokens to transfer
    *
    * Checks if at least one retailer is present
    * Makes a call to the contract transferTokens function and passes the sender of the order as an argument
    * The sender can be a Retailer or Customer
    * The 'to' can be a Retailer or Customer
    */
    function transferTokens(address to, uint amount) external {

        bool isReceiverRetailer = checkIfAddressIsRetailer(to);
        bool isSenderRetailer = checkIfAddressIsRetailer(_msgSender());

        require(isReceiverRetailer || isSenderRetailer , "Both users are Customers. One Retailer has to be present");

        LoyaltyMechanismType loyaltyMechanismType;

        if (isReceiverRetailer) {
            require(checkIfCustomerIsSubscribedToRetailer(to, _msgSender()), "The customer is not subscribed to retailer");
            loyaltyMechanismType = getLoyaltyMechanismType(to);
        }
        else {
            require(checkIfCustomerIsSubscribedToRetailer(_msgSender(), to), "The customer is not subscribed to retailer");
            loyaltyMechanismType = getLoyaltyMechanismType(_msgSender());
        }

        loyaltyMechanismContracts[loyaltyMechanismType].transferTokens(_msgSender(), to, amount, isSenderRetailer);
    }
}