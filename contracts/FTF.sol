// SPDX-License-Identifier: MIT
//Fruittex Forestry (FTF)
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "contracts/FFT.sol";

contract FTO is ERC721Enumerable, Ownable, Pausable {
    using SafeMath for uint256;


    uint256 public constant MAX_TOKENS = 1000000;
    uint256 private _nextTokenId = 1;
    address payable private _recipientAddress; 
    address private contractAddress;
    address[] private _tokenOwner;
    uint256[] private _totalTrees;
    uint256[] private _datePlanted;
    string[] private _cropType;
    string[] private _rootstock;
    string[] private _cultivar;
    uint256[] private _yieldPercentage;
     uint256[] private _term;
     string private _baseTokenURI;
     uint256 private _FTOMintFee;
     address private _fftContractAddress;
     address public newContractAddress;
    bool public isUpgraded = false;
    mapping(uint256 => string) private _tokenIPFSHash;
    uint256[] private _farmerTokenId;

   enum OrchardStatus {
    PendingPlanting,
    InProgress,
    HarvestReady,
    PostHarvest,
    UnderReplantation,
    UnderRehabilitation,
    Abandoned,
    Dormant,
    Active,
    Transferred,
    Retired
}

    mapping(uint256 => OrchardStatus) private _orchardStatus;
    mapping(uint256 => bool) private _tokenPaused;


    event TokenCreated(
        uint256 indexed tokenId,
        uint256 farmerTokenId,
        address indexed owner,
        uint256 totalTrees,
        uint256 datePlanted,
        string cropType,
        string rootstock,
        string cultivar,
        uint256 _FTOMintFee,
        address contractAddress,
        uint256 tokenProfitTerm,
        uint256 tokenProfitPercentage
    );
    event TokenTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );
    event TokenSold(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 price
    );
    event TokenMetadataUpdated(
        uint256 indexed tokenId,
        uint256 indexed datePlanted,
        string indexed cropType,
        string rootstock,
        string cultivar
    );


     event tokenProfitPercentageSet(
            uint256 indexed tokenId,
            uint256 yieldPercentage,
            address indexed from,
            address contractAddress
        );

     event tokenProfitTermSet(
    uint256 indexed tokenId,
    uint256 termInYears,
    address indexed setter,
    address indexed contractAddress
);
   
    event TokenBurned(uint256 indexed tokenId);
    event ContractUpgraded(address indexed oldContractAddress, address indexed newContractAddress);

    constructor(address fftContractAddress, uint256 mintFee) ERC721("Fruittex Orchard", "FTO") {
    _fftContractAddress = fftContractAddress;
    _FTOMintFee = mintFee;
    _recipientAddress = payable(msg.sender);

    }

 
 function setOrchardStatus(uint256 tokenId, OrchardStatus status) external onlyOwner {
    require(_exists(tokenId), "FTO: Token does not exist");

    _orchardStatus[tokenId] = status;

 
    if (status == OrchardStatus.Retired) {
        _pauseToken(tokenId);
    } else {
        _unpauseToken(tokenId);
    }
}

    function _pauseToken(uint256 tokenId) internal {
        require(!_tokenPaused[tokenId], "FTO: Token is already paused");
        _tokenPaused[tokenId] = true;
    }

    function _unpauseToken(uint256 tokenId) internal {
        require(_tokenPaused[tokenId], "FTO: Token is not paused");
        _tokenPaused[tokenId] = false;
    }

    function isTokenPaused(uint256 tokenId) public view returns (bool) {
        return _tokenPaused[tokenId];
    }

    function getFTODetails(uint256 tokenId) public view returns (
        uint256 totalTrees,
        uint256 datePlanted,
        string memory cropType,
        string memory rootstock,
        string memory cultivar,
        uint256 term,
        uint256 yieldPercentage,
        uint256 fftTokenId
    ) {
        require(_exists(tokenId), "FTO: Token does not exist");

        totalTrees = _totalTrees[tokenId - 1];
        datePlanted = _datePlanted[tokenId - 1];
        cropType = _cropType[tokenId - 1];
        rootstock = _rootstock[tokenId - 1];
        cultivar = _cultivar[tokenId - 1];
        fftTokenId = _farmerTokenId[tokenId - 1];
        term = _term[tokenId - 1];
        yieldPercentage = _yieldPercentage[tokenId - 1];
    }


    function setFFTContractAddress(address fftContractAddress) public onlyOwner {
        _fftContractAddress = fftContractAddress;
    }

     function setRecipientAddress(address payable newRecipientAddress) external onlyOwner {
        _recipientAddress = newRecipientAddress;
    }

   function getRecipientAddress() public view returns (address payable) {
    return _recipientAddress;
    }


    function setTokenIPFSHash(uint256 tokenId, string memory ipfsHash) public onlyOwner {
    require(_exists(tokenId), "FTO: Token does not exist");
    _tokenIPFSHash[tokenId] = ipfsHash;
}


    function getTokenIPFSHash(uint256 tokenId) public view returns (string memory) {
    require(_exists(tokenId), "FTO: Token does not exist");
    return _tokenIPFSHash[tokenId];
    }

  
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

    function setFTOMintFee(uint256 mintFee) external onlyOwner {
        _FTOMintFee = mintFee;
    }
    function getFTOMintFee() public view returns (uint256) {
        return _FTOMintFee;
    }

  

   function createToken(
        uint256 totalTrees,
        uint256 datePlanted,
        string memory cropType,
        string memory rootstock,
        string memory cultivar,
        address fftContractAddress,
        uint256 farmerTokenId,
        uint256 term,
        uint256 yieldPercentage
        
    ) public payable {
        require(
            _nextTokenId <= MAX_TOKENS,
            "FTO: Maximum number of tokens reached"
        );
        require(totalTrees > 0, "FTO: Invalid total trees count");

    
        require(
            FFT(fftContractAddress).doesFarmerExist(farmerTokenId),
            "FTO: Farmer token does not exist"
        );

   
        require(
            FFT(fftContractAddress).balanceOf(msg.sender) > 0,
            "FTO: No FFT token exists for the owner"
        );

        uint256 tokenId = _nextTokenId;
        _nextTokenId = _nextTokenId.add(1);

        _tokenOwner.push(msg.sender); 
        _totalTrees.push(totalTrees);
        _datePlanted.push(datePlanted);
        _cropType.push(cropType);
        _rootstock.push(rootstock);
        _cultivar.push(cultivar);
        _term.push(term);
        _yieldPercentage.push(yieldPercentage);
        _farmerTokenId.push(farmerTokenId);
        _safeMint(msg.sender, tokenId);
       

        require(msg.value >= _FTOMintFee, "FTO: Insufficient FTO Minting fee");
        _recipientAddress.transfer(_FTOMintFee);

       FFT(fftContractAddress).associateFTOWithFFT(farmerTokenId, tokenId);
 
        emit TokenCreated(
            tokenId,
            farmerTokenId,
            msg.sender,
            totalTrees,
            datePlanted,
            cropType,
            rootstock,
            cultivar,
            _FTOMintFee,
            address(this),
            term,
            yieldPercentage
        );
          
    }


    function isOwnerOf(address owner, uint256 tokenId) public view returns (bool) {
    return ownerOf(tokenId) == owner;
    }

    function tokenExists(uint256 tokenId)
        public
        view
        returns (bool)
    {
        return _exists(tokenId);
    }

    struct TokenInfo {
        uint256 tokenId;
        uint256 totalTrees;
        uint256 datePlanted;
        string cropType;
        string rootstock;
        string cultivar; 
        uint256 term;
        uint256 yieldPercentage;
        address ownerAddress;
        address fftContractAddress; 
        uint256 farmerTokenId; 
    }

function getFTOTokens() external view returns (TokenInfo[] memory) {
    uint256 totalSupply = totalSupply();
    TokenInfo[] memory allTokens = new TokenInfo[](totalSupply);

    for (uint256 i = 0; i < totalSupply; i++) {
        uint256 tokenId = tokenByIndex(i);
        allTokens[i] = getTokenInfo(tokenId);
    }

    return allTokens;
}

function getAllFTOTokensByFFT(uint256 farmerTokenId) external view returns (TokenInfo[] memory) {
    uint256 totalSupply = totalSupply();
    TokenInfo[] memory farmerTokens = new TokenInfo[](totalSupply);
    uint256 tokenCount = 0;

    for (uint256 i = 0; i < totalSupply; i++) {
        uint256 tokenId = tokenByIndex(i);
        if (_farmerTokenId[tokenId - 1] == farmerTokenId) {
            farmerTokens[tokenCount++] = getTokenInfo(tokenId);
        }
    }

    // Resize the array to fit the actual number of tokens
    assembly {
        mstore(farmerTokens, tokenCount)
    }

    return farmerTokens;
}



function calculateTotalTreesForAllFTOs() public view returns (uint256) {
    uint256 totalTrees = 0;

    for (uint256 i = 0; i < _nextTokenId - 1; i++) {
        address tokenOwner = ownerOf(i + 1);
        if (tokenOwner != address(0)) {
            totalTrees += _totalTrees[i];
        }
    }

    return totalTrees;
}


 function calculateTotalFTOTreesByOwner(address owner) public view returns (uint256) {
    uint256 totalTrees = 0;

    for (uint256 i = 0; i < _nextTokenId - 1; i++) {
        address tokenOwner = ownerOf(i + 1);
        if (tokenOwner == owner) {
            totalTrees += _totalTrees[i];
        }
    }

    return totalTrees;
}

        function burnToken(uint256 tokenId) external onlyOwner {
    require(_exists(tokenId), "FTO: Token does not exist");

    _burn(tokenId);
    delete _totalTrees[tokenId];
    delete _datePlanted[tokenId];
    delete _cropType[tokenId];
    delete _rootstock[tokenId];
    delete _cultivar[tokenId];

    emit TokenBurned(tokenId);
}

    function updateTokenMetadata(
        uint256 tokenId,
        uint256 datePlanted,
        string memory cropType,
        string memory rootstock,
        string memory cultivar

    ) public {
        require(_exists(tokenId), "FTO: Token does not exist");
        require(
            _tokenOwner[tokenId] == msg.sender,
            "FTO: Caller is not the token owner"
        );

        _datePlanted[tokenId] = datePlanted;
        _cropType[tokenId] = cropType;
        _rootstock[tokenId] = rootstock;
        _cultivar[tokenId] = cultivar;

        emit TokenMetadataUpdated(
            tokenId,
            datePlanted,
            cropType,
            rootstock,
            cultivar
        );
    }

function getAllFTOTokensByOwner(address owner) public view returns (TokenInfo[] memory) {
    uint256 tokenCount = balanceOf(owner);
    TokenInfo[] memory allTokens = new TokenInfo[](tokenCount);

    for (uint256 i = 0; i < tokenCount; i++) {
        uint256 tokenId = tokenOfOwnerByIndex(owner, i);
        allTokens[i] = getTokenInfo(tokenId);
    }

    return allTokens;
}


    function getTotalFTObyOwner(address owner) public view returns (uint256) {
    uint256 totalFTO = 0;

    for (uint256 i = 0; i < _tokenOwner.length; i++) {
        if (_tokenOwner[i] == owner) {
            totalFTO++;
        }
    }

    return totalFTO;
}

function getTotalFTObyFFT(uint256 farmerTokenId) public view returns (uint256) {
    uint256 totalFTO = 0;

    for (uint256 i = 0; i < _nextTokenId - 1; i++) {
        if (_farmerTokenId[i] == farmerTokenId) {
            totalFTO++;
        }
    }

    return totalFTO;
}


    function getTreeCount(uint256 ftoTokenId) public view returns (uint256) {
        require(_exists(ftoTokenId), "FTO: FTO token does not exist");
        return _totalTrees[ftoTokenId - 1];
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

function getTokenInfo(uint256 tokenId) public view returns (TokenInfo memory) {
    require(tokenId > 0 && tokenId <= _nextTokenId, "FTO: Invalid tokenId");
    uint256 index = tokenId - 1;
    return TokenInfo({
        tokenId: tokenId,
        totalTrees: _totalTrees[index],
        datePlanted: _datePlanted[index],
        cropType: _cropType[index],
        rootstock: _rootstock[index],
        cultivar: _cultivar[index],
        term: _term[index],
        yieldPercentage: _yieldPercentage[index],
        fftContractAddress: _fftContractAddress,
        farmerTokenId: _farmerTokenId[index],
        ownerAddress: ownerOf(tokenId)
    });
}




}
