// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICocaTrace {

    enum BatchStatus {
        Draft,
        Authorized,
        InTransit,
        AtMarket,
        Delivered
    }

    enum CardType {
        Yungas,
        Detalle
    }
    
    struct Batch {
        string producerId;
        string harvestLocation;
        uint256 taquesCount;
        string destination;
        BatchStatus status;
    }

    event BatchCreated(uint256 indexed tokenId, address indexed producer, uint256 taquesCount);
    event BatchAuthorized(uint256 indexed tokenId, address indexed validator, string destination);
    event BatchTransferred(uint256 indexed tokenId, address indexed from, address indexed to, BatchStatus newStatus);
    event FinalSale(uint256 indexed tokenId, address indexed seller, address indexed buyer);

    function registerProducerCard(CardType _cardType, string memory _department) external;
    function createBatch(string memory _producerId, string memory _harvestLocation, uint256 _taquesCount) external;
    function authorizeBatch(uint256 tokenId, string memory _destination) external;
    function moveBatch(uint256 tokenId) external;
    function marketCheck(uint256 tokenId) external;
    function felcnCheck(uint256 tokenId, address destinationAddress) external;
    function getBatchDetails(uint256 tokenId) external view returns (string memory, string memory, uint256, string memory, BatchStatus);
}