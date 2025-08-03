// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CocaTrace.sol";
import "../src/interfaces/ICocaTrace.sol";

contract CocaTraceTest is Test {
    CocaTrace public cocaTrace;
    
    address public owner;
    address public producer1;
    address public producer2;
    address public yungasValidator;
    address public felcnValidator;
    address public marketValidator;
    address public buyer;
    
    function setUp() public {
        owner = address(this);
        producer1 = makeAddr("producer1");
        producer2 = makeAddr("producer2");
        yungasValidator = makeAddr("yungasValidator");
        felcnValidator = makeAddr("felcnValidator");
        marketValidator = makeAddr("marketValidator");
        buyer = makeAddr("buyer");
        
        cocaTrace = new CocaTrace();
        
        // Set up validators
        cocaTrace.setYungasValidator(yungasValidator, true);
        cocaTrace.setFelcnValidator(felcnValidator, true);
        cocaTrace.setMarketValidator(marketValidator, true);
    }
    
    // Test initial deployment
    function testInitialState() public view {
        assertEq(cocaTrace.name(), "CocaLeafBatch");
        assertEq(cocaTrace.symbol(), "CLB");
        assertEq(cocaTrace.owner(), address(this));
        assertTrue(cocaTrace.isYungasValidator(address(this)));
        assertTrue(cocaTrace.isFelcnValidator(address(this)));
        assertTrue(cocaTrace.isMarketValidator(address(this)));
    }
    
    // Test producer card registration
    function testRegisterProducerCard() public {
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        // Corregimos el assert usando uint8 casting
        assertEq(uint8(cocaTrace.producerCardType(producer1)), uint8(ICocaTrace.CardType.Yungas));
    }
    
    function testRegisterProducerCardWithDepartment() public {
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Detalle, "La Paz");
        
        assertEq(uint8(cocaTrace.producerCardType(producer1)), uint8(ICocaTrace.CardType.Detalle));
        assertEq(cocaTrace.producerCardDepartment(producer1), "La Paz");
    }
    
    function testCannotRegisterCardTwice() public {
        vm.startPrank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.expectRevert("Producer already has a card");
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Detalle, "Cochabamba");
        vm.stopPrank();
    }
    
    function testDetalleCardRequiresDepartment() public {
        vm.prank(producer1);
        vm.expectRevert("Department must be specified for 'Detalle' card");
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Detalle, "");
    }
    
    // Test batch creation
    function testCreateBatch() public {
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        vm.expectEmit(true, true, false, true);
        emit ICocaTrace.BatchCreated(0, producer1, 10);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        // Verify batch details
        (string memory producerId, string memory location, uint256 taques, string memory destination, ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        
        assertEq(producerId, "PROD001");
        assertEq(location, "Yungas Region");
        assertEq(taques, 10);
        assertEq(destination, "");
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.Draft));
        
        // Check ownership
        assertEq(cocaTrace.ownerOf(0), producer1);
    }
    
    function testCannotCreateBatchWithoutCard() public {
        vm.prank(producer1);
        vm.expectRevert("Producer must register a card first");
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
    }
    
    function testCannotCreateBatchWithInvalidTaques() public {
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        vm.expectRevert("Batch must be between 1 and 20 taques");
        cocaTrace.createBatch("PROD001", "Yungas Region", 0);
        
        vm.prank(producer1);
        vm.expectRevert("Batch must be between 1 and 20 taques");
        cocaTrace.createBatch("PROD001", "Yungas Region", 21);
    }
    
    // Test batch authorization
    function testAuthorizeBatch() public {
        // Setup: Create a batch
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        // Authorize batch
        vm.prank(yungasValidator);
        vm.expectEmit(true, true, false, true);
        emit ICocaTrace.BatchAuthorized(0, yungasValidator, "La Paz");
        cocaTrace.authorizeBatch(0, "La Paz");
        
        // Verify authorization
        (, , , string memory destination, ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        assertEq(destination, "La Paz");
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.Authorized));
    }
    
    function testAuthorizeBatchWithDetalleCard() public {
        // Setup: Create a batch with Detalle card
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Detalle, "La Paz");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        // Should succeed with matching department
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        (, , , string memory destination, ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        assertEq(destination, "La Paz");
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.Authorized));
    }
    
    function testCannotAuthorizeWithWrongDepartmentForDetalle() public {
        // Setup: Create a batch with Detalle card
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Detalle, "La Paz");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        // Should fail with different department
        vm.prank(yungasValidator);
        vm.expectRevert("Destination does not match producer's card department");
        cocaTrace.authorizeBatch(0, "Cochabamba");
    }
    
    function testOnlyYungasValidatorCanAuthorize() public {
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(producer1);
        vm.expectRevert("Only Yungas Validator can authorize");
        cocaTrace.authorizeBatch(0, "La Paz");
    }
    
    // Test batch movement
    function testMoveBatch() public {
        // Setup: Create and authorize a batch
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        // Move batch
        vm.prank(producer1);
        vm.expectEmit(true, true, true, true);
        emit ICocaTrace.BatchTransferred(0, producer1, producer1, ICocaTrace.BatchStatus.InTransit);
        cocaTrace.moveBatch(0);
        
        // Verify status
        (, , , , ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.InTransit));
    }
    
    function testOnlyOwnerCanMoveBatch() public {
        // Setup
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        // Try to move as different user
        vm.prank(producer2);
        vm.expectRevert("Caller is not the producer");
        cocaTrace.moveBatch(0);
    }
    
    // Test market check
    function testMarketCheck() public {
        // Setup: Create, authorize, and move a batch
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        vm.prank(producer1);
        cocaTrace.moveBatch(0);
        
        // Market check
        vm.prank(marketValidator);
        vm.expectEmit(true, true, true, true);
        emit ICocaTrace.BatchTransferred(0, producer1, producer1, ICocaTrace.BatchStatus.AtMarket);
        cocaTrace.marketCheck(0);
        
        // Verify status
        (, , , , ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.AtMarket));
    }
    
    function testOnlyMarketValidatorCanCheck() public {
        // Setup
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        vm.prank(producer1);
        cocaTrace.moveBatch(0);
        
        // Try market check as non-validator
        vm.prank(producer1);
        vm.expectRevert("Only Market Validator can perform this check");
        cocaTrace.marketCheck(0);
    }
    
    // Test FELCN check
    function testFelcnCheck() public {
        // Setup: Full flow to AtMarket
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        vm.prank(producer1);
        cocaTrace.moveBatch(0);
        
        vm.prank(marketValidator);
        cocaTrace.marketCheck(0);
        
        // FELCN check
        vm.prank(felcnValidator);
        vm.expectEmit(true, true, true, true);
        emit ICocaTrace.BatchTransferred(0, producer1, buyer, ICocaTrace.BatchStatus.Delivered);
        cocaTrace.felcnCheck(0, buyer);
        
        // Verify final status and ownership
        (, , , , ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.Delivered));
        assertEq(cocaTrace.ownerOf(0), buyer);
    }
    
    function testOnlyFelcnValidatorCanCheck() public {
        // Setup to AtMarket
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 10);
        
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        vm.prank(producer1);
        cocaTrace.moveBatch(0);
        
        vm.prank(marketValidator);
        cocaTrace.marketCheck(0);
        
        // Try FELCN check as non-validator
        vm.prank(producer1);
        vm.expectRevert("Only FELCN Validator can perform this check");
        cocaTrace.felcnCheck(0, buyer);
    }
    
    // Test validator management
    function testSetValidators() public {
        address newValidator = makeAddr("newValidator");
        
        // Test setting Yungas validator
        cocaTrace.setYungasValidator(newValidator, true);
        assertTrue(cocaTrace.isYungasValidator(newValidator));
        
        cocaTrace.setYungasValidator(newValidator, false);
        assertFalse(cocaTrace.isYungasValidator(newValidator));
        
        // Test setting FELCN validator
        cocaTrace.setFelcnValidator(newValidator, true);
        assertTrue(cocaTrace.isFelcnValidator(newValidator));
        
        // Test setting Market validator
        cocaTrace.setMarketValidator(newValidator, true);
        assertTrue(cocaTrace.isMarketValidator(newValidator));
    }
    
    function testOnlyOwnerCanSetValidators() public {
        address newValidator = makeAddr("newValidator");
        
        vm.prank(producer1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, producer1));
        cocaTrace.setYungasValidator(newValidator, true);
    }
    
    // Test complete workflow
    function testCompleteWorkflow() public {
        // 1. Register producer
        vm.prank(producer1);
        cocaTrace.registerProducerCard(ICocaTrace.CardType.Yungas, "");
        
        // 2. Create batch
        vm.prank(producer1);
        cocaTrace.createBatch("PROD001", "Yungas Region", 15);
        
        // 3. Authorize batch
        vm.prank(yungasValidator);
        cocaTrace.authorizeBatch(0, "La Paz");
        
        // 4. Move batch
        vm.prank(producer1);
        cocaTrace.moveBatch(0);
        
        // 5. Market check
        vm.prank(marketValidator);
        cocaTrace.marketCheck(0);
        
        // 6. FELCN check and transfer
        vm.prank(felcnValidator);
        cocaTrace.felcnCheck(0, buyer);
        
        // Verify final state
        (, , , string memory destination, ICocaTrace.BatchStatus status) = cocaTrace.getBatchDetails(0);
        assertEq(destination, "La Paz");
        assertEq(uint8(status), uint8(ICocaTrace.BatchStatus.Delivered));
        assertEq(cocaTrace.ownerOf(0), buyer);
    }
}