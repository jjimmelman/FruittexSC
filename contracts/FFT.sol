// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// The FTO contract interface
interface IFTO {
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}



contract FFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    IFTO private _ftoContract;
   

    mapping(uint256 => uint256[]) private _ftoTokens;
  

struct FarmData {
    uint256 tokenId;
    string name;
    string location;
    string streetAddress;
    string city;
    string country;
    uint256 sizeInHectares;
    string farmOwnershipReference;
    bool isVerified;
    uint256 farmerTokenId; 
    }
    mapping(uint256 => FarmData) private _farmData;
    mapping(uint256 => string) private _tokenIPFSHash;
    mapping(address => uint256[]) private _farmsByOwner;
    address private contractAddress;
    address payable private _recipientAddress; 
   uint256 private _totalVerifiedFarms;
    uint256 private _totalUnverifiedFarms;
    mapping(address => uint256) private _totalVerifiedFarmsByOwner;
    mapping(address => uint256) private _totalUnverifiedFarmsByOwner;


    event FFTTokenCreated(
        uint256 indexed tokenId,
        address indexed owner,
        string tokenURI,
        string name,
        string location,
        string streetAddress,
        string city,
        string country,
        string farmOwnershipReference,
        uint256 sizeInHectares,
        uint256 _farmVerificationFee,
        address recipientAddress,
        address contractAddress
    );

   event FarmVerified(
    uint256 indexed tokenId,
    address contractAddress,
    address contractOwner,
    address tokenOwner
);

    event FarmUnverified(
        uint256 indexed tokenId,
    address contractAddress,
    address contractOwner,
    address tokenOwner
    );

    event FarmDataUpdated(
    uint256 indexed tokenId,
    string name,
    string location,
    string streetAddress,
    string city,
    string country,
    string farmOwnershipReference,
    uint256 sizeInHectares
    );


    constructor() ERC721("Fruittex Farm", "FFT") {
        _farmVerificationFee = 0; 
        _recipientAddress = payable(msg.sender); 
            
        }
 
    function setRecipientAddress(address payable newRecipientAddress) external onlyOwner {
        _recipientAddress = newRecipientAddress;
    }
     function getRecipientAddress() public view returns (address payable) {
    return _recipientAddress;
    }

      function setFTOContractAddress(address ftoContractAddress) external onlyOwner {
        _ftoContract = IFTO(ftoContractAddress);
    }

    function getFTOContractAddress() public view returns (address) {
    return address(_ftoContract);
    }

    
    uint256 private _farmVerificationFee;
    function setFarmVerficationFee(uint256 feeToVerify) external onlyOwner {
        _farmVerificationFee = feeToVerify;
    }
    function getVerificationFee() public view returns (uint256) {
        return _farmVerificationFee;
    }

   function mint(
    string memory name,
    string memory location,
    string memory streetAddress,
    string memory city,
    string memory country,
    string memory farmOwnershipReference,
    uint256 sizeInHectares
) public payable  {
    uint256 tokenId = _tokenIdCounter.current() + 1;
    _tokenIdCounter.increment();

    FarmData memory farm = FarmData({
        tokenId: tokenId,
        name: name,
        location: location,
        streetAddress: streetAddress,
        city: city,
        country: country,
        farmOwnershipReference: farmOwnershipReference,
        sizeInHectares: sizeInHectares,
        isVerified: false,
        farmerTokenId: 1 // Initialize the farmerTokenId to 1
    });

    _farmData[tokenId] = farm;
    _mint(msg.sender, tokenId);
    _farmsByOwner[msg.sender].push(tokenId);

    // Increase the count of total unverified farms
    _totalUnverifiedFarms++;
    _totalUnverifiedFarmsByOwner[msg.sender]++;


    // Emit the FFTTokenCreated event
    emit FFTTokenCreated(
        tokenId,
        msg.sender,
        tokenURI(tokenId),
        name,
        location,
        streetAddress,
        city,
        country,
        farmOwnershipReference,
        sizeInHectares,
        _farmVerificationFee,
        _recipientAddress,
        address(this)
    );

    // Apply farm Verification Fee
    require(msg.value >= _farmVerificationFee, "FTT: Insufficient merge fee");
    _recipientAddress.transfer(_farmVerificationFee);
}


    function updateFarmData(
        uint256 tokenId,
        string memory name,
        string memory location,
        string memory streetAddress,
        string memory city,
        string memory country,
        string memory farmOwnershipReference,
        uint256 sizeInHectares

    ) external onlyOwner {
        require(_exists(tokenId), "FFT: Token does not exist");

        FarmData storage farm = _farmData[tokenId];
        require(!farm.isVerified, "FFT: Farm is already verified");

        farm.name = name;
        farm.location = location;
        farm.streetAddress = streetAddress;
        farm.city = city;
        farm.country = country;
        farm.farmOwnershipReference;
        farm.sizeInHectares = sizeInHectares;

        emit FarmDataUpdated(
        tokenId,
        name,
        location,
        streetAddress,
        city,
        country,
        farmOwnershipReference,
        sizeInHectares
    );

    }

 function verifyFarm(uint256 tokenId) external onlyOwner {
    require(_exists(tokenId), "FFT: Token does not exist");
    FarmData storage farm = _farmData[tokenId];
    require(!farm.isVerified, "FFT: Farm is already verified");
    farm.isVerified = true;

    // Increment the counters
    _totalVerifiedFarms++;
    _totalUnverifiedFarms--;
    _totalVerifiedFarmsByOwner[ownerOf(tokenId)]++;
    _totalUnverifiedFarmsByOwner[ownerOf(tokenId)]--;


    emit FarmVerified(tokenId, address(this), owner(), ownerOf(tokenId));
}

function unverifyFarm(uint256 tokenId) external onlyOwner {
    require(_exists(tokenId), "FFT: Token does not exist");
    FarmData storage farm = _farmData[tokenId];
    require(farm.isVerified, "FFT: Farm is not verified");
    farm.isVerified = false;

    // Decrement the counters
    _totalVerifiedFarms--;
    _totalUnverifiedFarms++;
    _totalVerifiedFarmsByOwner[ownerOf(tokenId)]--;
    _totalUnverifiedFarmsByOwner[ownerOf(tokenId)]++;


    emit FarmUnverified(tokenId, address(this), owner(), ownerOf(tokenId));
}



    function doesFarmerExist(uint256 farmerTokenId) external view returns (bool) {
    return _exists(farmerTokenId);
}


    function getFarmData(uint256 tokenId) public view returns (FarmData memory) {
        require(_exists(tokenId), "FFT: Token does not exist");
        return _farmData[tokenId];
    }

    
    

    function totalTokensSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

       function getFarmsByOwner(address owner) public view returns (FarmData[] memory) {
        uint256[] storage farms = _farmsByOwner[owner];
        FarmData[] memory ownerFarms = new FarmData[](farms.length);

        for (uint256 i = 0; i < farms.length; i++) {
            ownerFarms[i] = _farmData[farms[i]];
        }

        return ownerFarms;
    }


    function listAllFarms() public view returns (FarmData[] memory) {
        FarmData[] memory farms = new FarmData[](_tokenIdCounter.current());

    for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
    farms[i] = _farmData[i];
    }
        return farms;
    }

       string private _baseTokenURI;

    function setBaseURI(string memory baseTokenURI) public onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    function _setTokenURI(uint256 tokenId, string memory ipfsHash) internal {
    require(_exists(tokenId), "FFT: Token does not exist");
    _tokenIPFSHash[tokenId] = ipfsHash;
}

    function setTokenIPFSHash(uint256 tokenId, string memory ipfsHash) external onlyOwner {
        _setTokenURI(tokenId, ipfsHash);
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

  
 

    function getTotalVerifiedFarms() public view returns (uint256) {
        return _totalVerifiedFarms;
    }

 
    function getTotalNotVerifiedFarms() public view returns (uint256) {
    return _totalUnverifiedFarms;
}


    function getTotalVerifiedFarmsByOwner(address owner) public view returns (uint256) {
        return _totalVerifiedFarmsByOwner[owner];
    }

    function getTotalNotVerifiedFarmsByOwner(address owner) public view returns (uint256) {
        return _totalUnverifiedFarmsByOwner[owner];
    }



   function associateFTOWithFFT(uint256 fftTokenId, uint256 ftoTokenId) external {
    require(msg.sender == address(_ftoContract), "FFT: Only the FTO contract can associate FTO tokens.");
    require(_exists(fftTokenId), "FFT: FFT token does not exist.");

    _ftoTokens[fftTokenId].push(ftoTokenId);
}

function transferFFT(address to, uint256 fftTokenId) external {
    require(ownerOf(fftTokenId) == msg.sender, "FFT: Only the FFT owner can transfer the token.");

    // Check if the owner of the FFT token also owns the associated FTO tokens
    for (uint256 i = 0; i < _ftoTokens[fftTokenId].length; i++) {
        uint256 ftoTokenId = _ftoTokens[fftTokenId][i];
        require(_ftoContract.ownerOf(ftoTokenId) == msg.sender, "FFT: FFT owner does not own associated FTO token.");
    }

    // Transfer FFT token
    safeTransferFrom(msg.sender, to, fftTokenId);

    // Transfer associated FTO tokens
    for (uint256 i = 0; i < _ftoTokens[fftTokenId].length; i++) {
        uint256 ftoTokenId = _ftoTokens[fftTokenId][i];
        _ftoContract.safeTransferFrom(msg.sender, to, ftoTokenId);
    }
}


}