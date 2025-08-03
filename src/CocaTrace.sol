// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICocaTrace.sol";

contract CocaTrace is ERC721, Ownable, ICocaTrace {

    // Cambiamos el contador de `Counters.Counter` a un simple `uint256`.
    uint256 private _tokenIdCounter;

    mapping(address => bool) public isYungasValidator;
    mapping(address => bool) public isFelcnValidator;
    mapping(address => bool) public isMarketValidator;

    mapping(uint256 => Batch) public batches;
    mapping(address => CardType) public producerCardType;
    mapping(address => string) public producerCardDepartment;
    mapping(address => bool) private hasRegisteredCard;

    constructor()
        ERC721("CocaLeafBatch", "CLB")
        Ownable(msg.sender)
    {
        isYungasValidator[msg.sender] = true;
        isFelcnValidator[msg.sender] = true;
        isMarketValidator[msg.sender] = true;
    }

    function setYungasValidator(address _validator, bool _status) public onlyOwner {
        isYungasValidator[_validator] = _status;
    }

    function setFelcnValidator(address _validator, bool _status) public onlyOwner {
        isFelcnValidator[_validator] = _status;
    }

    function setMarketValidator(address _validator, bool _status) public onlyOwner {
        isMarketValidator[_validator] = _status;
    }

    function registerProducerCard(CardType _cardType, string memory _department) public {
        require(!hasRegisteredCard[msg.sender], "Producer already has a card");
        
        if (_cardType == CardType.Detalle) {
            require(bytes(_department).length > 0, "Department must be specified for 'Detalle' card");
            producerCardDepartment[msg.sender] = _department;
        }

        producerCardType[msg.sender] = _cardType;
        hasRegisteredCard[msg.sender] = true;
    }

    function createBatch(string memory _producerId, string memory _harvestLocation, uint256 _taquesCount) public {
        require(hasRegisteredCard[msg.sender], "Producer must register a card first");
        require(_taquesCount > 0 && _taquesCount <= 20, "Batch must be between 1 and 20 taques");

        // Usamos el contador directamente
        uint256 newItemId = _tokenIdCounter;
        _safeMint(msg.sender, newItemId);
        
        batches[newItemId] = Batch({
            producerId: _producerId,
            harvestLocation: _harvestLocation,
            taquesCount: _taquesCount,
            destination: "",
            status: BatchStatus.Draft
        });
        
        // Incrementamos el contador
        _tokenIdCounter++;
        emit BatchCreated(newItemId, msg.sender, _taquesCount);
    }

    function authorizeBatch(uint256 tokenId, string memory _destination) public {
        require(isYungasValidator[msg.sender], "Only Yungas Validator can authorize");
        Batch storage batch = batches[tokenId];
        require(batch.status == BatchStatus.Draft, "Batch not in Draft status");
        
        address producerAddress = ownerOf(tokenId);
        if (producerCardType[producerAddress] == CardType.Detalle) {
            string memory allowedDepartment = producerCardDepartment[producerAddress];
            require(
                keccak256(abi.encodePacked(_destination)) == keccak256(abi.encodePacked(allowedDepartment)),
                "Destination does not match producer's card department"
            );
        }

        batch.destination = _destination;
        batch.status = BatchStatus.Authorized;
        
        emit BatchAuthorized(tokenId, msg.sender, _destination);
    }
    
    function moveBatch(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the producer");
        Batch storage batch = batches[tokenId];
        require(batch.status == BatchStatus.Authorized, "Batch not authorized for movement");
        
        batch.status = BatchStatus.InTransit;
        emit BatchTransferred(tokenId, msg.sender, msg.sender, BatchStatus.InTransit);
    }

    function marketCheck(uint256 tokenId) public {
        require(isMarketValidator[msg.sender], "Only Market Validator can perform this check");
        Batch storage batch = batches[tokenId];
        require(batch.status == BatchStatus.InTransit, "Batch not in transit");

        batch.status = BatchStatus.AtMarket;
        emit BatchTransferred(tokenId, ownerOf(tokenId), ownerOf(tokenId), BatchStatus.AtMarket);
    }

    function felcnCheck(uint256 tokenId, address destinationAddress) public {
        require(isFelcnValidator[msg.sender], "Only FELCN Validator can perform this check");
        Batch storage batch = batches[tokenId];
        require(batch.status == BatchStatus.AtMarket, "Batch is not at the market");
        
        batch.status = BatchStatus.Delivered;
        
        address currentOwner = ownerOf(tokenId);
        _transfer(currentOwner, destinationAddress, tokenId);
        
        emit BatchTransferred(tokenId, currentOwner, destinationAddress, BatchStatus.Delivered);
    }

    function getBatchDetails(uint256 tokenId) public view returns (string memory, string memory, uint256, string memory, BatchStatus) {
        Batch storage batch = batches[tokenId];
        return (batch.producerId, batch.harvestLocation, batch.taquesCount, batch.destination, batch.status);
    }
}