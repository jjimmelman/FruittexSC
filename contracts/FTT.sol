// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "contracts/FTO.sol";


contract FTT is ERC721, Ownable, Pausable, ReentrancyGuard{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

 struct FTTData {
    uint256 ftoTokenId;
    uint256 fttTokenId;
    uint256 treeCount;
    address owner;
    bool isSold;
     
}

    FTO private _ftoContract;
    mapping(uint256 => uint256) private _treeCounts;
    mapping(uint256 => uint256) private _treesPerFTT;
    mapping(uint256 => uint256) private _fttToFtoMapping;
    uint256 private _maxTreesPerFTO;
    uint256 private _mintingFee;
    address private _approvedSpender;
    address payable private _recipientAddress; 
    uint256 private _totalTreeCount;
    mapping(uint256 => string) private _tokenIPFSHash;
    address private contractAddress;
    address public newContractAddress;
    bool public isUpgraded = false;
    address private _ftoContractAddress;
  
    event MintingFeePaid(address indexed payer, address indexed recipient, uint256 amount);
    event MintEvent(
        uint256 indexed ftoTokenId, 
        uint256 indexed tokenId, 
        uint256 treeCount, 
        address owner,
        address contractAddress,
        uint256 _mintingFee, 
        string tokenURI
        );
    event bulkTokensMinted(
      uint256 indexed tokenId, 
      uint256 treeCount, 
      address indexed owner,
       address contractAddress, 
      uint256 ftoTokenId,
      uint256 _mintingFee
      );   
    event splitTokensCreated(
        uint256 indexed tokenId, 
        uint256 treeCount, 
        address indexed owner, 
        address contractAddress,
        uint256 ftoTokenId,
        uint256 _splitFee
    );
    event splitTokenBurned(
        uint256 indexed tokenId, 
        uint256 treeCount, 
        address indexed owner, 
        address contractAddress,
        uint256 ftoTokenId
    );
    event mergeTokenBurned(
        uint256 burnedTokenId, 
        uint256 treeCount, 
        address contractAddress, 
        address indexed owner,
        uint256 ftoTokenId
    );
    event mergeTokenAdjusted(
        uint256 mergedTokenId, 
        uint256 treeCount, 
        address contractAddress, 
        address indexed owner, 
        uint256 ftoTokenId,
        uint256 _mergeFee
    );
     event transferFromEvent(
         address from, 
         address to, 
         uint256 indexed tokenId,
         address indexed owner,
         address contractAddress,
         uint256 ftoTokenId,
         uint256 totalTrees
    );
    event approveFTTMarketPlaceOnceEvent(
        address indexed FTTMarketPlaceAddress, 
        address indexed owner,
        address contractAddress
    );
    event disapproveFTTMarketPlaceOnceEvent(
        address indexed FTTMarketPlaceAddress, 
        address indexed owner,
        address contractAddress
    );
    event burnFTTEvent(
        uint256 indexed tokenId,
        uint256 treeCount, 
        address contractAddress, 
        address indexed owner, 
        uint256 ftoTokenId 
    );
    event withdrawEvent(
        address fromAddress, 
        address indexed recipientAddress, 
        address contractAddress, 
        uint256 amount
    );
     event setRecipientAddressEvent(
        address indexed recipientAddress,
        address fromAddress, 
        address indexed owner, 
        address contractAddress
    );
    event setMintingFeeEvent(
        address fromAddress, 
        address indexed owner, 
        address contractAddress,
        uint256 mintingFee
    );
    event setSplitFeeEvent(
        address fromAddress, 
        address indexed owner, 
        address contractAddress,
        uint256 splitFee
    );
    event setMergeFeeEvent(
        address fromAddress, 
        address indexed owner, 
        address contractAddress,
        uint256 mergeFee
    );

    event setApprovedSpenderEvent(
        address indexed spender,
        address fromAddress, 
        address indexed owner, 
        address contractAddress
        );

    event ContractUpgraded(address indexed oldContractAddress, address indexed newContractAddress);
   
 constructor(address ftoContractAddress, uint256 maxTreesPerFTO, uint256 mintingFeeInWei, uint256 feeToSplit, uint256 feeToMerge) ERC721("Fruittex Trees", "FTT") {
    _ftoContract = FTO(ftoContractAddress);
    _maxTreesPerFTO = maxTreesPerFTO;
    _mintingFee = mintingFeeInWei;
    _splitFee = feeToSplit;
    _mergeFee = feeToMerge;
    _recipientAddress = payable(msg.sender); 
    contractAddress = address(this);
}

   function setFtoContractAddress(address ftoContractAddress) public onlyOwner {
        _ftoContractAddress = ftoContractAddress;
    }


    function getContractAddress() public view returns (address) {
        return contractAddress;
    }

    function setMintingFee(uint256 feeInWei) external onlyOwner {
        _mintingFee = feeInWei;

       emit setMintingFeeEvent(msg.sender, owner(), address(this), _mintingFee);  
    }

    function setTreeCount(uint256 tokenId, uint256 treeCount) external onlyOwner {
        _treeCounts[tokenId] = treeCount;
    }
    function setRecipientAddress(address payable newRecipientAddress) external onlyOwner {
        _recipientAddress = newRecipientAddress;

        emit setRecipientAddressEvent(_recipientAddress, msg.sender, owner(), address(this));

    }
     function getRecipientAddress() public view returns (address payable) {
    return _recipientAddress;
    }

    function getMintingFee(uint256 treeCount, uint256 treesPerFTT) public view returns (uint256) {
    uint256 fttMintCount = treeCount / treesPerFTT;
    uint256 fttRemainder = treeCount % treesPerFTT;
    if (fttRemainder > 0) {
        fttMintCount += 1;
    }
    uint256 mintingFee = _mintingFee * fttMintCount;

    return mintingFee;
}


function approveFTTMarketPlaceOnce(address payable FTTMarketPlaceAddress) public {
   
    setApprovalForAll(FTTMarketPlaceAddress, true);
    emit approveFTTMarketPlaceOnceEvent(FTTMarketPlaceAddress, msg.sender, address(this));
}

function disapproveFTTMarketPlaceOnce(address FTTMarketPlaceAddress) public {
   
    setApprovalForAll(FTTMarketPlaceAddress, false);

     emit disapproveFTTMarketPlaceOnceEvent(FTTMarketPlaceAddress, msg.sender, address(this));
}

function getApprovalStatus(address FTTMarketPlaceAddress) public view returns (bool) {
   
    return isApprovedForAll(owner(), FTTMarketPlaceAddress);
}


function mint(uint256 ftoTokenId, uint256 treeCount, address owner, uint256 treesPerFTT) public payable whenNotPaused{
    require(_ftoContract.getTreeCount(ftoTokenId) > 0, "FTT: Invalid FTO token ID");
    require(treeCount > 0, "FTT: Invalid tree count");
    require(treesPerFTT > 0, "FTT: Invalid trees per FTT");
    uint256 existingFTTsTreeCount = getTotalTreeCountByFto(owner, ftoTokenId);
    uint256 remainingTreeCount = _ftoContract.getTreeCount(ftoTokenId) - existingFTTsTreeCount;

    require(treeCount <= remainingTreeCount, "FTT: Exceeds available tree count for FTO");

    uint256 fttMintCount = treeCount / treesPerFTT;
    uint256 fttRemainder = treeCount % treesPerFTT;
    if (fttRemainder > 0) {
        fttMintCount += 1;
    }

    uint256 mintingFee = _mintingFee * fttMintCount;

    require(msg.value >= mintingFee, "FTT: Insufficient payment");

   
    _recipientAddress.transfer(mintingFee);
    emit MintingFeePaid(msg.sender, _recipientAddress, mintingFee);

    for (uint256 i = 0; i < fttMintCount; i++) {
        uint256 currentFttCount = i == fttMintCount - 1 && fttRemainder > 0 ? fttRemainder : treesPerFTT;
        uint256 tokenId = _tokenIds.current() + 1;
        _mint(owner, tokenId);
        _tokenIds.increment();
        _treeCounts[tokenId] = currentFttCount;
        _treesPerFTT[tokenId] = treesPerFTT;
        _fttToFtoMapping[tokenId] = ftoTokenId;

        emit MintEvent(
            ftoTokenId,
            tokenId,
            currentFttCount,
            owner,
            address(this),
            _mintingFee,
            tokenURI(tokenId) 
        );
    }
}

    

   function mintBulk(uint256 ftoTokenId, uint256[] memory treeCounts, address owner) public payable whenNotPaused{
    require(_ftoContract.getTreeCount(ftoTokenId) > 0, "FTT: Invalid FTO token ID");
    
 
    
    uint256 existingFTTsTreeCount = getTotalTreeCountByFto(owner, ftoTokenId);
    uint256 remainingTreeCount = _ftoContract.getTreeCount(ftoTokenId) - existingFTTsTreeCount;
    
    uint256 totalMintingFee = _mintingFee * treeCounts.length;
    
    require(msg.value >= totalMintingFee, "FTT: Insufficient payment");
    
   
    _recipientAddress.transfer(totalMintingFee);
    emit MintingFeePaid(msg.sender, _recipientAddress, totalMintingFee);
    
    uint256 tokenId = _tokenIds.current() + 1;
    
    for (uint256 i = 0; i < treeCounts.length; i++) {
        uint256 treeCount = treeCounts[i];
        
        require(treeCount > 0, "FTT: Invalid tree count");
        require(treeCount <= remainingTreeCount, "FTT: Exceeds available tree count for FTO");
        
        _mint(owner, tokenId);
        _tokenIds.increment();
        _treeCounts[tokenId] = treeCount;
        _treesPerFTT[tokenId] = 1;  
        _fttToFtoMapping[tokenId] = ftoTokenId;
        
      
        emit bulkTokensMinted(tokenId, treeCount, owner, address(this), ftoTokenId, _mintingFee);

        tokenId++;
    }
}

            uint256 private _splitFee;
            uint256 public splitFee;
            function setSplitFee(uint256 feeToSplit) external onlyOwner {
                _splitFee = feeToSplit;

                emit setSplitFeeEvent(msg.sender, owner(), address(this), _splitFee); 
            }

            function getSplitFee() public view returns (uint256) {
                return _splitFee;
            }


        function splitFTT(uint256 tokenId, uint256 newTokenCount) external payable whenNotPaused{
        require(_exists(tokenId), "FTT: Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "FTT: Sender does not own the token");
        require(newTokenCount > 0, "FTT: Invalid new token count");
        uint256 treeCount = _treeCounts[tokenId];
        require(treeCount % newTokenCount == 0, "FTT: Tree count is not divisible by the new token count");
        uint256 treesPerNewToken = treeCount / newTokenCount;
        uint256 originalMappingValue = _fttToFtoMapping[tokenId];

        for (uint256 i = 0; i < newTokenCount; i++) {
            uint256 newTokenId = _tokenIds.current() + 1;
            _mint(msg.sender, newTokenId);
            _tokenIds.increment();
            _treeCounts[newTokenId] = treesPerNewToken;
            _treesPerFTT[newTokenId] = treesPerNewToken;
        _fttToFtoMapping[newTokenId] = originalMappingValue; 

            emit splitTokensCreated(newTokenId, treesPerNewToken, msg.sender, address(this), _fttToFtoMapping[tokenId], _splitFee);
        }

     
        uint256 splitFeeTotal = _splitFee * newTokenCount;
        require(msg.value >= splitFeeTotal, "FTT: Insufficient split fee");
        _recipientAddress.transfer(splitFeeTotal);

        emit splitTokenBurned(tokenId, treeCount, msg.sender, address(this), _fttToFtoMapping[tokenId]);

        delete _fttToFtoMapping[tokenId];
        _burn(tokenId);
        delete _treeCounts[tokenId];
        delete _treesPerFTT[tokenId];
        delete _fttToFtoMapping[tokenId];
    }

    uint256 private _mergeFee;
    function setMergeFee(uint256 feeToMerge) external onlyOwner {
        _mergeFee = feeToMerge;

        emit setMergeFeeEvent(msg.sender, owner(), address(this), _mergeFee); 
    }
    function getMergeFee() public view returns (uint256) {
        return _mergeFee;
    }

    function mergeFTT(uint256[] memory tokenIds, uint256 mergedTokenId) external payable whenNotPaused{
    require(tokenIds.length > 1, "FTT: Must provide at least two token IDs");
    require(_exists(mergedTokenId), "FTT: Merged token ID does not exist");

    uint256 totalTrees = 0;
    uint256 ftoId = _fttToFtoMapping[tokenIds[0]];  

    for (uint256 i = 0; i < tokenIds.length; i++) {
        uint256 tokenId = tokenIds[i];
        require(_exists(tokenId), "FTT: Token ID does not exist");
        require(ownerOf(tokenId) == msg.sender, "FTT: Sender does not own the token");
        require(_fttToFtoMapping[tokenId] == ftoId, "FTT: Tokens must belong to the same FTO");

        uint256 treeCount = _treeCounts[tokenId];
        totalTrees += treeCount;

      
        _burn(tokenId);
        delete _treeCounts[tokenId];
        delete _treesPerFTT[tokenId];
        delete _fttToFtoMapping[tokenId];

       
        emit mergeTokenBurned(tokenId, treeCount, address(this), msg.sender, ftoId);

    }

 
    _fttToFtoMapping[mergedTokenId] = ftoId;
    require(msg.value >= _mergeFee, "FTT: Insufficient merge fee");
    _recipientAddress.transfer(_mergeFee);
    _treeCounts[mergedTokenId] += totalTrees;

    emit mergeTokenAdjusted(mergedTokenId, _treeCounts[mergedTokenId], address(this), msg.sender, ftoId, _mergeFee);
}

        
    function getTotalTreeCountByFto(address owner, uint256 ftoTokenId) public view returns (uint256) {
        uint256 fttCount = balanceOf(owner);
        uint256 totalTrees = 0;

        for (uint256 i = 0; i < fttCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            uint256 ftoId = getFtoTokenId(tokenId);

            if (ftoId == ftoTokenId) {
                totalTrees += _treeCounts[tokenId];
            }
        }

        return totalTrees;
    }



function getTotalFTTmintedByFtoOwner(address owner) public view returns (uint256) {
    uint256 totalTrees = 0;
    uint256 ftoCount = balanceOf(owner);

    for (uint256 i = 0; i < ftoCount; i++) {
        uint256 ftoTokenId = tokenOfOwnerByIndex(owner, i);
        uint256 treesInFTT = getTreesInFTT(ftoTokenId);
        totalTrees += treesInFTT;
    }

    return totalTrees;
}

function getTreesInFTT(uint256 ftoTokenId) internal view returns (uint256) {
    uint256 totalTrees = 0;
    uint256 fttCount = _tokenIds.current();

    for (uint256 tokenId = 1; tokenId <= fttCount; tokenId++) {
        if (_exists(tokenId) && getFtoTokenId(tokenId) == ftoTokenId) {
            totalTrees += _treeCounts[tokenId];
        }
    }

    return totalTrees;
}


    function getFtoTokenId(uint256 fttTokenId) public view returns (uint256) {
        return _fttToFtoMapping[fttTokenId];
    }

    function getFtoTreeCount(uint256 tokenId) public view returns (uint256) {
        uint256 ftoTokenId = getFtoTokenId(tokenId);
        return _ftoContract.getTreeCount(ftoTokenId);
    }

    function getFTTsByOwner(address owner) public view returns (FTTData[] memory) {
    uint256 fttCount = balanceOf(owner);
    FTTData[] memory fttData = new FTTData[](fttCount);

    for (uint256 i = 0; i < fttCount; i++) {
        uint256 tokenId = tokenOfOwnerByIndex(owner, i);
        uint256 ftoTokenId = getFtoTokenId(tokenId); 
        fttData[i] = FTTData({
            ftoTokenId: ftoTokenId, 
            fttTokenId: tokenId,
            treeCount: _treeCounts[tokenId],
            owner: owner,
            isSold: false
            
        });
    }

    return fttData;
    }

function getFTTDataByTokenId(uint256 fttTokenId) public view returns (FTTData memory) {
    require(_exists(fttTokenId), "FTT token does not exist");

    FTTData memory fttData;

    fttData = FTTData({
        ftoTokenId: getFtoTokenId(fttTokenId),
        fttTokenId: fttTokenId,
        treeCount: _treeCounts[fttTokenId],
        owner: ownerOf(fttTokenId),
        isSold: false
    });

    return fttData;
}



    
    function countTotalTreesByOwner(address owner) public view returns (uint256) {
        uint256 fttCount = balanceOf(owner);
        uint256 totalTrees = 0;

        for (uint256 i = 0; i < fttCount; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, i);
            totalTrees += _treeCounts[tokenId];
        }

        return totalTrees;
    }

    function listAllFTTs() public view returns (FTTData[] memory) {
    uint256 fttCount = _tokenIds.current();
    FTTData[] memory fttData = new FTTData[](fttCount);

    uint256 dataCount = 0;

    for (uint256 tokenId = 1; tokenId <= fttCount; tokenId++) {
        if (_exists(tokenId)) {
            uint256 treeCount = _treeCounts[tokenId];
            address owner = ownerOf(tokenId);
            uint256 ftoTokenId = getFtoTokenId(tokenId); 

            fttData[dataCount] = FTTData({
                ftoTokenId: ftoTokenId,
                fttTokenId: tokenId,
                treeCount: treeCount,
                owner: owner,
                isSold: false
            });
            dataCount++;
        }
    }

  
    if (dataCount < fttCount) {
        FTTData[] memory resizedData = new FTTData[](dataCount);
        for (uint256 i = 0; i < dataCount; i++) {
            resizedData[i] = fttData[i];
        }
        fttData = resizedData;
    }

    return fttData;
}




    function listAllFTTsByFto(uint256 ftoTokenId) public view returns (FTTData[] memory) {
    uint256 fttCount = _tokenIds.current();
    FTTData[] memory fttData = new FTTData[](fttCount);
    uint256 dataCount = 0;

    for (uint256 tokenId = 1; tokenId <= fttCount; tokenId++) {
        if (_exists(tokenId)) {
            uint256 treeCount = _treeCounts[tokenId];
            address owner = ownerOf(tokenId);
            uint256 ftoId = getFtoTokenId(tokenId);

            if (ftoId == ftoTokenId) {
                fttData[dataCount] = FTTData({
                    ftoTokenId: ftoId,
                    fttTokenId: tokenId,
                    treeCount: treeCount,
                    owner: owner,
                    isSold: false
                });
                dataCount++;
            }
        }
    }

    
    if (dataCount < fttCount) {
        FTTData[] memory resizedData = new FTTData[](dataCount);
        for (uint256 i = 0; i < dataCount; i++) {
            resizedData[i] = fttData[i];
        }
        fttData = resizedData;
    }

    return fttData;
}

function listAllOwnerFTTsByFto(uint256 ftoTokenId, address walletAddress) public view returns (FTTData[] memory) {
    uint256 fttCount = _tokenIds.current();
    FTTData[] memory fttData = new FTTData[](fttCount);
    uint256 dataCount = 0;

    for (uint256 tokenId = 1; tokenId <= fttCount; tokenId++) {
        if (_exists(tokenId)) {
            uint256 treeCount = _treeCounts[tokenId];
            address owner = ownerOf(tokenId);
            uint256 ftoId = getFtoTokenId(tokenId);

            if (ftoId == ftoTokenId && owner == walletAddress) {
                fttData[dataCount] = FTTData({
                    ftoTokenId: ftoId,
                    fttTokenId: tokenId,
                    treeCount: treeCount,
                    owner: owner,
                    isSold: false
                });
                dataCount++;
            }
        }
    }

  
    if (dataCount < fttCount) {
        FTTData[] memory resizedData = new FTTData[](dataCount);
        for (uint256 i = 0; i < dataCount; i++) {
            resizedData[i] = fttData[i];
        }
        fttData = resizedData;
    }

    return fttData;
}




    function getTotalTreeCount(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "FTT: Token does not exist");
        return _treeCounts[tokenId];
    }

    
    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }


  function getTotalFTTtreeCount() public view returns (uint256) {
    uint256 totalTrees = 0;
    for (uint256 i = 1; i <= totalSupply(); i++) {
        totalTrees += _treeCounts[i];
    }
    return totalTrees;
    }

        function burnFTT(uint256 tokenId) external {
            require(_exists(tokenId), "FTT: Token does not exist");
            require(ownerOf(tokenId) == msg.sender, "FTT: Sender does not own the token");

            _burn(tokenId);
            delete _treeCounts[tokenId];
            delete _treesPerFTT[tokenId];
            delete _fttToFtoMapping[tokenId];

            uint256 ftoTokenId = getFtoTokenId(tokenId); 
            uint256 fttTreeCount = getTotalTreeCount(tokenId);

            emit burnFTTEvent(tokenId, fttTreeCount, address(this), msg.sender, ftoTokenId);
        }

        function tokenOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
            require(index < balanceOf(owner), "FTT: Index out of bounds");

            uint256 tokenCount = 0;
            for (uint256 i = 1; i <= _tokenIds.current(); i++) {
                uint256 tokenId = i;
                if (_exists(tokenId) && ownerOf(tokenId) == owner) {
                    if (tokenCount == index) {
                        return tokenId;
                    }
                    tokenCount++;
                }
            }
            revert("FTT: No token found for the provided index");
        }

        function uintToString(uint256 value) internal pure returns (string memory) {
            if (value == 0) {
                return "0";
            }
            uint256 temp = value;
            uint256 digits;
            while (temp != 0) {
                digits++;
                temp /= 10;
            }
            bytes memory buffer = new bytes(digits);
            while (value != 0) {
                digits -= 1;
                buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
                value /= 10;
            }
            return string(buffer);
        }

        function setTokenIPFSHash(uint256 tokenId, string memory ipfsHash) public onlyOwner {
        require(_exists(tokenId), "FTO: Token does not exist");
        _tokenIPFSHash[tokenId] = ipfsHash;
    }


    function getTokenIPFSHash(uint256 tokenId) public view returns (string memory) {
    require(_exists(tokenId), "FTO: Token does not exist");
    return _tokenIPFSHash[tokenId];
    }


    string private _baseTokenURI;

    function setBaseURI(string memory baseTokenURI) public onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    function _setTokenURI(uint256 tokenId, string memory ipfsHash) internal {
    require(_exists(tokenId), "FFT: Token does not exist");
    _tokenIPFSHash[tokenId] = ipfsHash;
}

     function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "FTO: Token does not exist");

    string memory baseURI = _baseTokenURI;
    string memory ipfsHash = _tokenIPFSHash[tokenId];

    if (bytes(ipfsHash).length > 0) {
        return string(abi.encodePacked(baseURI, ipfsHash));
    } else {
        return "";
    }
}

    function setApprovedSpender(address spender) external onlyOwner {
        _approvedSpender = spender;

         emit setApprovedSpenderEvent(spender, msg.sender, owner(), address(this) );
    }

    function isApprovedSpender(address spender) public view returns (bool) {
        return spender == _approvedSpender;
    }

 

function transferFrom(address from, address to, uint256 tokenId) public override {
    super.transferFrom(from, to, tokenId);

    uint256 ftoTokenId = getFtoTokenId(tokenId); 
    uint256 fttTreeCount = getTotalTreeCount(tokenId);
   

    emit transferFromEvent(from, to, tokenId, msg.sender, address(this), ftoTokenId, fttTreeCount);
}



    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        require(
            _treesPerFTT[tokenId] == _treeCounts[tokenId] || isApprovedSpender(msg.sender),
            "FTT: Can only transfer entire FTT tokens or spender must be approved"
        );
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant{
    require(amount <= address(this).balance, "FTT: Withdraw amount exceeds balance");
    payable(owner()).transfer(amount);

    
    emit withdrawEvent(msg.sender, owner(), address(this), amount);

    }

      function upgradeContract(address _newContractAddress) external onlyOwner {
        newContractAddress = _newContractAddress;
        isUpgraded = true;
        emit ContractUpgraded(address(this), newContractAddress);
    }

    function getNewContractAddress() public view returns (address) {
        require(isUpgraded, "Contract has not been upgraded yet");
        return newContractAddress;
    }

       function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

}
