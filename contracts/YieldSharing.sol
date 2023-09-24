// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface FTTContract {
    function totalTreesPerFTT(uint256 fttTokenId) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface FTOContract {
    function getTokenProfitPercentage(uint256 ftoTokenId) external view returns (uint256);
    function totalTreesPerFTO(uint256 ftoTokenId) external view returns (uint256);
}

contract YieldSharing {
    FTTContract fttContract;
    FTOContract ftoContract;

    constructor(address _fttContractAddress, address _ftoContractAddress) {
        fttContract = FTTContract(_fttContractAddress);
        ftoContract = FTOContract(_ftoContractAddress);
    }

    function distributeProfit(uint256 distributedAmount, uint256 ftoTokenId) external payable {
        require(msg.value == distributedAmount, "Incorrect value sent");

        uint256 totalTrees = ftoContract.totalTreesPerFTO(ftoTokenId);
        require(totalTrees > 0, "Invalid FTO tokenId");

        uint256 profitShare = (distributedAmount * ftoContract.getTokenProfitPercentage(ftoTokenId)) / 100;
        require(profitShare > 0, "Invalid profit share");

        // Distribute profit to FTT holders based on their ownership of trees
        for (uint256 fttTokenId = 1; fttTokenId <= totalTrees; fttTokenId++) {
            address fttOwner = fttContract.ownerOf(fttTokenId);
            uint256 treesOwned = fttContract.totalTreesPerFTT(fttTokenId);

            // Calculate profit share per tree
            uint256 profitSharePerTree = profitShare / totalTrees;
            uint256 allocation = profitSharePerTree * treesOwned;

            // Transfer the profit allocation to the FTT token owner
            payable(fttOwner).transfer(allocation);
        }
    }
}
