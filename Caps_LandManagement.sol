// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

contract KYC {
    mapping(address => bool) public kycVerified;
    address public governmentAuthority;

    event KYCVerified(address indexed user);

    modifier onlyGovernmentAuthority() {
        require(msg.sender == governmentAuthority, "Permission denied: Not government authority");
        _;
    }

    constructor() {
        governmentAuthority = msg.sender;
    }

    function verifyKYC(address _user) external onlyGovernmentAuthority {
        kycVerified[_user] = true;
        emit KYCVerified(_user);
    }
}

contract KYCBuySellLands {

    struct Land {
        uint256 price;
        address owner;
        bool forSale;
        string landName;
        string description;
        string location;
    }

    mapping(address => bool) public landOwners;
    mapping(address => bool) public buyers;
    mapping(uint256 => Land) public lands;
    mapping(uint256 => address[]) public ownershipHistory;

    uint256[] public landIds;
    KYC public kycContract;

    event LandListed(address indexed landowner, uint256 landID, string landDescription, uint256 price);
    event PurchaseRequested(address indexed buyer, uint256 landID);
    event LandSold(address indexed buyer, address indexed landowner, uint256 landID, string landDescription, uint256 landPrice);
    event LandMarkedForSale(uint256 landID, uint256 price);
    modifier onlyKYCVerified() {
        require(kycContract.kycVerified(msg.sender), "Permission denied: KYC not verified");
        _;
    }

    modifier onlyBuyer() {
        require(buyers[msg.sender], "Permission denied: Not a buyer");
        _;
    }

    modifier onlyGovernmentAuthority() {
        require(msg.sender == kycContract.governmentAuthority(), "Permission denied: Not government authority");
        _;
    }

    constructor(address _kycContractAddress) {
        kycContract = KYC(_kycContractAddress);
    }

    function listLandForSale(uint256 _landId, uint256 _price, string memory _landName, string memory _description, string memory _location) public onlyKYCVerified {
        Land memory newLand = Land({
            price: _price,
            owner: msg.sender,
            forSale: true,
            landName: _landName,
            description: _description,
            location: _location
        });

        lands[_landId] = newLand;
        landIds.push(_landId);
        ownershipHistory[_landId].push(msg.sender); // Record the initial owner

        emit LandListed(msg.sender, _landId, _description, _price);
    }

    function requestToPurchase(uint256 _landId) external onlyBuyer onlyKYCVerified {
        emit PurchaseRequested(msg.sender, _landId);
    }

    function grantLandOwnerPermission(address _landowner) external onlyGovernmentAuthority {
        landOwners[_landowner] = true;
    }

    function grantBuyerPermission(address _buyer) external onlyGovernmentAuthority {
        buyers[_buyer] = true;
    }

    function buyLand(uint256 _landId) external payable onlyBuyer onlyKYCVerified {
        Land storage property = lands[_landId];

        require(property.forSale, "Property is not for Sale");
        require(property.price <= msg.value, "Insufficient Funds");
        ownershipHistory[_landId].push(property.owner);
        property.owner = msg.sender;
        property.forSale = false;

        // Transfer the purchase price to the seller
        payable(ownershipHistory[_landId][ownershipHistory[_landId].length - 2]).transfer(property.price);

        emit LandSold(msg.sender, property.owner, _landId, property.description, property.price);
    }

    function markLandForSale(uint256 _landId, uint256 _price) external {
        Land storage property = lands[_landId];
        require(msg.sender == property.owner, "Permission denied: Not the land owner");
        
        property.forSale = true;
        property.price = _price;

        emit LandMarkedForSale(_landId, _price);
    }

    function getOwnershipHistory(uint256 _landId) external view returns (address[] memory) {
        return ownershipHistory[_landId];
    }

    function getLand(uint256 _landId) external view returns (address, string memory, string memory, uint256, string memory, uint256, bool) {
        Land memory land = lands[_landId];
        return (land.owner, land.description, land.location, land.price, land.landName, _landId, land.forSale);
    }
}
