// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "contracts/FTT.sol"; 

contract FTTMarketPlace is Ownable {
    using Counters for Counters.Counter;

    struct Order {
    address seller;
    uint256 tokenId;
    uint256 treeCount;
    uint256 price;
    bool active;
    uint256 saleEndTime; 
    }

    mapping(uint256 => TokenClaim) private _tokenClaim;
    mapping(uint256 => uint256[]) private userClaimableTokens;

    struct TokenClaim {
    address seller;
    uint256 tokenId;
    uint256 treeCount;
    uint256 price;
    uint256 userId;
    bool active;
    }

    FTT private _fttContract; 

    mapping(address => uint256[]) private _tokensOfOwner;
    mapping(uint256 => Order) private _orders;
    
    Counters.Counter private _tokenIdTracker;
    uint256 private _sellingFee;
    address payable private _recipientAddress; 
    uint256 public _fulfillFeePercentage;
    uint256 public MAX_SALE_DURATION = 60 days;

    // Define the struct for token sale information
    struct TokenSale {
        uint256 tokenId;
        uint256 quantity;
        uint256 price;
        uint256 saleEndTime;
    }

    // Mapping to track token sales
    mapping(uint256 => TokenSale) public tokenSales;

    event orderPlacedEvent(
        uint256 indexed tokenId, 
        uint256 treeCount, 
        uint256 price, 
        address indexed seller, 
        address contractAddress, 
        uint256 saleEndTime,
        uint256 listingFee
        );
    event orderCancelledEvent(uint256 indexed tokenId, uint256 treeCount, address indexed seller, address contractAddress);

    event orderFulfilledEvent(
        uint256 indexed tokenId, 
        uint256 treeCount, 
        uint256 treeSellingPrice,
        address indexed seller, 
        address indexed buyer, 
        uint256 totalAmount, 
        uint256 sellerAmount, 
        uint256 fulfillFee,
        address contractAddress
        );
   
     event orderPriceUpdatedEvent(
         uint256 indexed tokenId, 
         uint256 treeCount, 
         uint256 price, 
         address indexed seller, 
         address contractAddress, 
         uint256 saleEndTime
         );
   
    
    event claimFulfilledEvent(
        uint256 indexed tokenId, 
        uint256 userId, 
        uint256 treeCount, 
        address indexed seller, 
        address indexed buyer, 
        uint256 totalAmount, 
        uint256 ftoTokenId, 
        address contractAddress);

    event claimableTokensCreatedEvent(
        uint256 indexed tokenId, 
        uint256 treeCount, 
        uint256 totalAmount, 
        address seller, 
        uint256 userId, 
        address contractAddress);

    event buyTokenValuesEvent(uint256 msgValue, uint256 totalAmount);

    constructor(address payable fttContractAddress, uint256 sellingFeeInWei, uint256 fulfillFeePercentage) {
    _fttContract = FTT(fttContractAddress); 
    _sellingFee = sellingFeeInWei;
    _recipientAddress = payable(msg.sender); 
    _fulfillFeePercentage = fulfillFeePercentage;
    }

    function setFTTContractAddress(address payable fttContractAddress) external onlyOwner {
     _fttContract = FTT(fttContractAddress);
    }

    function setSellingFee(uint256 feeInWei) external onlyOwner {
        _sellingFee = feeInWei;
    }

    function setRecipientAddress(address payable newRecipientAddress) external onlyOwner {
        _recipientAddress = newRecipientAddress;
    }


    function getSellingFee() public view returns (uint256) {
        uint256 sellingFee = _sellingFee; 
        return sellingFee;
    }

   function setMaxSaleDuration(uint256 duration) external onlyOwner {
        MAX_SALE_DURATION = duration;
    }

    function placeOrder(uint256 fttTokenId, uint256 treeCount, uint256 price, uint256 saleDuration) external payable {
        require(treeCount > 0, "Fruittex Market Place: Invalid tree count");
        require(price > 0, "Fruittex Market Place: Invalid price");

        // Check if the FTT token ID exists by verifying the owner address is not the zero address
        require(_fttContract.ownerOf(fttTokenId) != address(0), "FTT Market Place: Invalid FTT token ID");

        // Check if the message sender is the owner of the FTT token
        require(_fttContract.ownerOf(fttTokenId) == msg.sender, "FTT Market Place: Only the owner can place an order");



        // Calculate the token sale end time in seconds
        uint256 saleEndTime = block.timestamp + (saleDuration * 1 days);


        // Check if the token sale duration exceeds the maximum allowed
        require(saleDuration <= MAX_SALE_DURATION, "Token sale duration exceeds the maximum limit of 60 days");

        // Create a new order
        Order storage order = _orders[fttTokenId];
        order.seller = msg.sender;
        order.tokenId = fttTokenId;
        order.treeCount = treeCount;
        order.price = price;
        order.saleEndTime = saleEndTime;
        order.active = true;

        // Increment the token ID tracker
        _tokenIdTracker.increment();

        // Calculate and validate the selling fee
        uint256 sellingFee = getSellingFee();
        require(msg.value >= sellingFee, "FTTMarket Selling Fee: Insufficient payment");

        // Send the selling fee to the recipient address
        _recipientAddress.transfer(sellingFee);

        // Emit the OrderPlaced event
        emit orderPlacedEvent(fttTokenId, treeCount, price, msg.sender, address(this), saleEndTime, sellingFee);
    }


    function listTokenForSale(uint256 tokenId, uint256 price) public returns (address) {
        Order storage order = _orders[tokenId];

        // Calculate the token sale end time
        uint256 saleEndTime = block.timestamp + MAX_SALE_DURATION;

        // Check if the token sale duration exceeds the maximum allowed
        require(saleEndTime <= block.timestamp + MAX_SALE_DURATION, "Token sale duration exceeds the maximum limit of 60 days");

        require(order.active, "FTT Market Place: Order is not active");
        require(order.seller == msg.sender, "FTT Market Place: Caller is not the seller");

        require(price > 0, "FTT Market Place: Invalid price");
        require(order.price != price, "FTT Market Place: Order is already listed at this price");

        order.price = price;

        // Update the token sale information
        tokenSales[tokenId] = TokenSale(tokenId, order.treeCount, price, saleEndTime);

        emit orderPriceUpdatedEvent(tokenId, order.treeCount, price, msg.sender, address(this), order.saleEndTime);
 
        return address(this);
    }


    function CreateBulkClaimableTokens(uint256[] memory fttTokenIds, uint256[] memory treeCounts, uint256[] memory prices, uint256[] memory userIds) external payable {
    require(fttTokenIds.length == treeCounts.length && treeCounts.length == prices.length && prices.length == userIds.length, "Fruittex Market Place: Invalid input arrays");

    for (uint256 i = 0; i < fttTokenIds.length; i++) {
        uint256 fttTokenId = fttTokenIds[i];
        uint256 treeCount = treeCounts[i];
        uint256 price = prices[i];
        uint256 userId = userIds[i];

        require(treeCount > 0, "Fruittex Market Place: Invalid tree count");
        require(price >= 0, "Fruittex Market Place: Invalid price");

        // Check if the FTT token ID exists by verifying the owner address is not the zero address
        require(_fttContract.ownerOf(fttTokenId) != address(0), "FTT Market Place: Invalid FTT token ID");

        // Check if the message sender is the owner of the FTT token
        require(_fttContract.ownerOf(fttTokenId) == msg.sender, "FTT Market Place: Only the owner can place an order");

        _tokenClaim[fttTokenId] = TokenClaim({
            seller: msg.sender,
            tokenId: fttTokenId,
            treeCount: treeCount,
            price: price,
            userId: userId,
            active: true
        });
        _tokenIdTracker.increment();

        emit claimableTokensCreatedEvent(fttTokenId, treeCount, price, msg.sender, userId, address(this));

        // Update userClaimableTokens mapping
        userClaimableTokens[userId].push(fttTokenId);
    }
}


    function listClaimableTokensUserId(uint256 userId) public view returns (uint256[][] memory) {
        uint256[] storage tokenIds = userClaimableTokens[userId];
        uint256[][] memory tokenDetails = new uint256[][](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            tokenDetails[i] = new uint256[](4); // [tokenId, treeCount, price, active]
            tokenDetails[i][0] = tokenId;
            tokenDetails[i][1] = _tokenClaim[tokenId].treeCount;
            tokenDetails[i][2] = _tokenClaim[tokenId].price;
            tokenDetails[i][3] = _tokenClaim[tokenId].active ? 1 : 0;


        }

        return tokenDetails;
    }



function listAllClaimableTokens(bool onlyActive) public view returns (uint256[][] memory) {
    uint256 totalClaimableTokens = _tokenIdTracker.current();
    uint256[][] memory tokenDetails;
    uint256 activeTokenCount = 0;

    // Calculate the number of active tokens
    for (uint256 i = 0; i < totalClaimableTokens; i++) {
        uint256 tokenId = i + 1;
        if (_tokenClaim[tokenId].active) {
            activeTokenCount++;
        }
    }

    // Initialize the tokenDetails array based on the chosen status
    if (onlyActive) {
        tokenDetails = new uint256[][](activeTokenCount);
    } else {
        tokenDetails = new uint256[][](totalClaimableTokens);
    }

    // Populate the tokenDetails array with the chosen status
    uint256 index = 0;
    for (uint256 i = 0; i < totalClaimableTokens; i++) {
        uint256 tokenId = i + 1;
        if (_tokenClaim[tokenId].active || !onlyActive) {
            tokenDetails[index] = new uint256[](6); // [tokenId, treeCount, price, active, fttTokenId, ftoTokenId]
            tokenDetails[index][0] = tokenId;
            tokenDetails[index][1] = _tokenClaim[tokenId].treeCount;
            tokenDetails[index][2] = _tokenClaim[tokenId].price;
            tokenDetails[index][3] = _tokenClaim[tokenId].active ? 1 : 0; // Active or Inactive
            tokenDetails[index][4] = _getFTTDataByTokenId(tokenId).fttTokenId;
            tokenDetails[index][5] = _getFtoTokenId(tokenDetails[index][4]);
            index++;
        }
    }

    return tokenDetails;
}


   function getClaim(uint256 tokenId) public view returns (uint256, uint256, uint256, address, uint256, uint256) {
        require(_tokenClaim[tokenId].active, "Fruittex Market Place: Token claim not found");

        TokenClaim memory claim = _tokenClaim[tokenId];
        uint256 ftoTokenId = _getFtoTokenId(tokenId); // Get the ftoTokenId based on the tokenId

        return (
            claim.tokenId,
            claim.treeCount,
            claim.price,
            claim.seller,
            claim.userId,
            ftoTokenId
        );
    }



    function claimToken(uint256 tokenId) public payable {
        TokenClaim storage claim = _tokenClaim[tokenId];
        // Logging the values

        uint256 totalAmount = claim.price * claim.treeCount;

        require(claim.active, "FTT Trading: Claim is not active");
        require(claim.seller != msg.sender, "FTT Trading: Caller is the seller");
        require(msg.value == totalAmount, "FTT Trading: Incorrect ETH amount");

        // Transfer the tokens using the FTT contract's transfer function
        _fttContract.transferFrom(claim.seller, msg.sender, tokenId);       

        claim.active = false;
        _tokensOfOwner[msg.sender].push(tokenId);
        emit claimFulfilledEvent(tokenId, claim.userId, claim.treeCount, claim.seller, msg.sender, totalAmount, _getFtoTokenId(tokenId), address(this));
    }

    function cancelOrder(uint256 tokenId) public {
        Order storage order = _orders[tokenId];

        require(order.active, "Fruittex Market Place: Order is not active");
        require(order.seller == msg.sender, "Fruittex Market Place: Caller is not the seller");

        order.active = false;

        emit orderCancelledEvent(tokenId, order.treeCount, msg.sender, address(this));
       
    }

    function getTokensForSale() public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](_tokenIdTracker.current());
        uint256 tokenIndex = 0;
        for (uint256 i = 1; i <= _tokenIdTracker.current(); i++) {
            if (_orders[i].active) {
                tokenIds[tokenIndex] = _orders[i].tokenId;
                tokenIndex++;
            }
        }
        // Trim the tokenIds array to remove unused elements
        assembly {
            mstore(tokenIds, tokenIndex)
        }
        uint256[] memory result = new uint256[](tokenIndex);
        for (uint256 i = 0; i < tokenIndex; i++) {
            result[i] = tokenIds[i];
        }
        return result;
    }


    function getTokensForSaleByFTO(uint256 ftoTokenId) public view returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](_tokenIdTracker.current());
        uint256 tokenIndex = 0;
        for (uint256 i = 1; i <= _tokenIdTracker.current(); i++) {
            if (_orders[i].active && _fttContract.getFtoTokenId(_orders[i].tokenId) == ftoTokenId) {
                tokenIds[tokenIndex] = _orders[i].tokenId;
                tokenIndex++;
            }
        }
        // Trim the tokenIds array to remove unused elements
        assembly {
            mstore(tokenIds, tokenIndex)
        }
        uint256[] memory result = new uint256[](tokenIndex);
        for (uint256 i = 0; i < tokenIndex; i++) {
            result[i] = tokenIds[i];
        }
        return result;
    }


    function setFulfillFeePercentage(uint256 percentage) public onlyOwner {
        require(percentage <= 100, "FTTMarketPlace: Invalid percentage"); // Ensure the percentage is not greater than 100
        _fulfillFeePercentage = percentage;
    }

    
    function buyToken(uint256 tokenId) public payable {
        Order storage order = _orders[tokenId];
        // Logging the values
    
        uint256 totalAmount = order.price * order.treeCount;
        uint256 fulfillFee = (totalAmount * _fulfillFeePercentage) / 100;
        uint256 sellerAmount = totalAmount - fulfillFee;
       
        require(order.active, "FTT Trading: Order is not active");
        require(order.seller != msg.sender, "FTT Trading: Caller is the seller"); 
        require(msg.value == totalAmount, "FTT Trading: Incorrect ETH amount");

        // Transfer the tokens using the FTT contract's transfer function
        _fttContract.transferFrom(order.seller, msg.sender, tokenId);

        payable(_recipientAddress).transfer(fulfillFee); // Transfer fulfillFee to recipientAddress
        payable(order.seller).transfer(sellerAmount); // Transfer remaining balance to the seller

        order.active = false;
        _tokensOfOwner[msg.sender].push(tokenId);

        emit orderFulfilledEvent(tokenId, order.treeCount, order.price, order.seller, msg.sender, totalAmount, sellerAmount, fulfillFee, address(this));
   
    }

    function getOrder(uint256 tokenId) public view returns (Order memory) {
     return _orders[tokenId];
    }

    function isOrderActive(uint256 tokenId) public view returns (bool) {
       return _orders[tokenId].active;
    }

    function getOrderTotalAmount(uint256 tokenId) public view returns (uint256) {
        Order storage order = _orders[tokenId];
        require(order.active, "FTT Market Place: Order is not active");
      return order.price * order.treeCount;
    }

    function totalTrees(uint256 tokenId) public view returns (uint256) {
     return _orders[tokenId].treeCount;
    }

    function totalTreesForSale() public view returns (uint256) {
        uint256 _totalTrees = 0;
        uint256 tokenId;

        for (tokenId = 1; tokenId <= _tokenIdTracker.current(); tokenId++) {
            Order storage order = _orders[tokenId];
            if (order.active && order.seller != address(0)) {
                _totalTrees += order.treeCount;
            }
        }

        return _totalTrees;
    }

    function totalTreesForSaleByFTO(uint256 ftoTokenId) public view returns (uint256) {
        uint256 _totalTrees = 0;
        uint256 tokenId;

        for (tokenId = 1; tokenId <= _tokenIdTracker.current(); tokenId++) {
            Order storage order = _orders[tokenId];
            if (order.active && _fttContract.getFtoTokenId(order.tokenId) == ftoTokenId) {
                _totalTrees += order.treeCount;
            }
        }

        return _totalTrees;
    }

 function _getFTTDataByTokenId(uint256 tokenId) public view returns (FTT.FTTData memory) {
    return _fttContract.getFTTDataByTokenId(tokenId);
}


function _getFtoTokenId(uint256 fttTokenId) public view returns (uint256) {
    return _fttContract.getFtoTokenId(fttTokenId);
}


    function getFTTsByOwner(address owner) public view returns (FTT.FTTData[] memory) {
        return _fttContract.getFTTsByOwner(owner);
    }

    function getListAllFTTsByFto(uint256 ftoTokenId) public view returns (FTT.FTTData[] memory) {
        return _fttContract.listAllFTTsByFto(ftoTokenId);
    }

    function getListAllFTTs() public view returns (FTT.FTTData[] memory) {
        return _fttContract.listAllFTTs();
    }


    function getTokenIdTracker() public view returns (uint256) {
     return _tokenIdTracker.current();
    }


    function getTokenSeller(uint256 tokenId) public view returns (address) {
      return _orders[tokenId].seller;
    }

    function getTokenTreeCount(uint256 tokenId ) public view returns (uint256) {
      return _orders[tokenId].treeCount;
    }

     function getTokenPrice(uint256 tokenId) public view returns (uint256) {
        return _orders[tokenId].price;
    }

     function getTokenSaleEndTime(uint256 tokenId) public view returns (uint256) {
        return _orders[tokenId].saleEndTime;
    }

       
    function withdraw() public onlyOwner {
        require(_recipientAddress != address(0), "Recipient address not set");
        uint256 balance = address(this).balance;
        _recipientAddress.transfer(balance);
        }

        enum TransactionType {
            PlaceOrder,
            CancelOrder,
            FulfillOrder
            // Add more transaction types as needed
    }    

    receive() external payable {
    emit buyTokenValuesEvent(msg.value, 0);
    }
}
