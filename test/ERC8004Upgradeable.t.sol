// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IdentityRegistryUpgradeable.sol";
import "../src/ReputationRegistryUpgradeable.sol";
import "../src/ValidationRegistryUpgradeable.sol";
import "../src/ERC1967Proxy.sol";
import "../src/MockERC1271Wallet.sol";

contract ERC8004UpgradeableTest is Test {
    IdentityRegistryUpgradeable public identityRegistryImpl;
    IdentityRegistryUpgradeable public identityRegistry;
    ReputationRegistryUpgradeable public reputationRegistryImpl;
    ReputationRegistryUpgradeable public reputationRegistry;
    ValidationRegistryUpgradeable public validationRegistryImpl;
    ValidationRegistryUpgradeable public validationRegistry;
    MockERC1271Wallet public mockWallet;

    ERC1967Proxy public identityProxy;
    ERC1967Proxy public reputationProxy;
    ERC1967Proxy public validationProxy;

    address public owner;
    address public agent1;
    address public client1;
    address public validator1;
    address public operator1;
    uint256 public agentOwnerKey;
    uint256 public client1Key;
    uint256 public operatorKey;

    function setUp() public {
        owner = address(this);
        agentOwnerKey = 0xA11CE;
        client1Key = 0xB0B;
        operatorKey = 0x0123;

        agent1 = vm.addr(agentOwnerKey);
        client1 = vm.addr(client1Key);
        operator1 = vm.addr(operatorKey);
        validator1 = address(0x4);

        // Deploy implementations
        identityRegistryImpl = new IdentityRegistryUpgradeable();
        reputationRegistryImpl = new ReputationRegistryUpgradeable();
        validationRegistryImpl = new ValidationRegistryUpgradeable();

        // Deploy proxies
        identityProxy = new ERC1967Proxy(
            address(identityRegistryImpl),
            abi.encodeWithSelector(IdentityRegistryUpgradeable.initialize.selector)
        );

        reputationProxy = new ERC1967Proxy(
            address(reputationRegistryImpl),
            abi.encodeWithSelector(ReputationRegistryUpgradeable.initialize.selector, address(identityProxy))
        );

        validationProxy = new ERC1967Proxy(
            address(validationRegistryImpl),
            abi.encodeWithSelector(ValidationRegistryUpgradeable.initialize.selector, address(identityProxy))
        );

        // Cast proxies to implementation interfaces
        identityRegistry = IdentityRegistryUpgradeable(address(identityProxy));
        reputationRegistry = ReputationRegistryUpgradeable(address(reputationProxy));
        validationRegistry = ValidationRegistryUpgradeable(address(validationProxy));
    }

    // ============ Upgradeable Tests ============

    function testIdentityRegistryInitialization() public {
        assertEq(identityRegistry.owner(), owner);
        assertEq(identityRegistry.name(), "AgentIdentity");
        assertEq(identityRegistry.symbol(), "AID");
    }

    function testReputationRegistryInitialization() public {
        assertEq(reputationRegistry.getIdentityRegistry(), address(identityProxy));
        assertEq(reputationRegistry.owner(), owner);
    }

    function testValidationRegistryInitialization() public {
        assertEq(validationRegistry.getIdentityRegistry(), address(identityProxy));
        assertEq(validationRegistry.owner(), owner);
    }

    function testCannotReinitializeIdentityRegistry() public {
        vm.expectRevert();
        identityRegistry.initialize();
    }

    function testCannotReinitializeReputationRegistry() public {
        vm.expectRevert();
        reputationRegistry.initialize(address(identityRegistry));
    }

    function testCannotReinitializeValidationRegistry() public {
        vm.expectRevert();
        validationRegistry.initialize(address(identityRegistry));
    }

    function testUpgradeIdentityRegistry() public {
        // Register an agent before upgrade
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register("ipfs://before");

        // Deploy new implementation
        IdentityRegistryUpgradeable newImpl = new IdentityRegistryUpgradeable();

        // Upgrade
        identityRegistry.upgradeToAndCall(address(newImpl), "");

        // Verify state persisted
        assertEq(identityRegistry.ownerOf(agentId), agent1);
        assertEq(identityRegistry.tokenURI(agentId), "ipfs://before");
    }

    function testUpgradeReputationRegistry() public {
        // Register agent and give feedback before upgrade
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        // Deploy new implementation
        ReputationRegistryUpgradeable newImpl = new ReputationRegistryUpgradeable();

        // Upgrade
        reputationRegistry.upgradeToAndCall(address(newImpl), "");

        // Verify state persisted
        (uint8 score, , , bool isRevoked) = reputationRegistry.readFeedback(agentId, client1, 1);
        assertEq(score, 85);
        assertFalse(isRevoked);
    }

    function testUpgradeValidationRegistry() public {
        // Register agent and create validation request before upgrade
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        // Deploy new implementation
        ValidationRegistryUpgradeable newImpl = new ValidationRegistryUpgradeable();

        // Upgrade
        validationRegistry.upgradeToAndCall(address(newImpl), "");

        // Verify state persisted
        (address validator, uint256 returnedAgentId, , , , ) = validationRegistry.getValidationStatus(requestHash);
        assertEq(validator, validator1);
        assertEq(returnedAgentId, agentId);
    }

    function testOnlyOwnerCanUpgradeIdentityRegistry() public {
        IdentityRegistryUpgradeable newImpl = new IdentityRegistryUpgradeable();

        vm.prank(agent1);
        vm.expectRevert();
        identityRegistry.upgradeToAndCall(address(newImpl), "");
    }

    function testOnlyOwnerCanUpgradeReputationRegistry() public {
        ReputationRegistryUpgradeable newImpl = new ReputationRegistryUpgradeable();

        vm.prank(agent1);
        vm.expectRevert();
        reputationRegistry.upgradeToAndCall(address(newImpl), "");
    }

    function testOnlyOwnerCanUpgradeValidationRegistry() public {
        ValidationRegistryUpgradeable newImpl = new ValidationRegistryUpgradeable();

        vm.prank(agent1);
        vm.expectRevert();
        validationRegistry.upgradeToAndCall(address(newImpl), "");
    }

    function testGetVersion() public {
        assertEq(identityRegistry.getVersion(), "1.0.0");
        assertEq(reputationRegistry.getVersion(), "1.0.0");
        assertEq(validationRegistry.getVersion(), "1.0.0");
    }

    // ============ Functional Tests with Upgradeable Contracts ============

    function testRegisterAndGiveFeedbackUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register("ipfs://agent");

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        (uint8 score, , , bool isRevoked) = reputationRegistry.readFeedback(agentId, client1, 1);
        assertEq(score, 85);
        assertFalse(isRevoked);
    }

    function testValidationRequestAndResponseUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        vm.prank(validator1);
        validationRegistry.validationResponse(requestHash, 95, "ipfs://response", keccak256("data"), keccak256("tag"));

        (, , uint8 response, , , ) = validationRegistry.getValidationStatus(requestHash);
        assertEq(response, 95);
    }

    function testMetadataSetAndRetrieveUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setMetadata(agentId, "name", bytes("Agent1"));

        assertEq(identityRegistry.getMetadata(agentId, "name"), bytes("Agent1"));
    }

    function testOperatorCanSignFeedbackAuthUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setApprovalForAll(operator1, true);

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, operatorKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        assertEq(reputationRegistry.getLastIndex(agentId, client1), 1);
    }

    function testERC1271WalletCanSignFeedbackAuthUpgradeable() public {
        mockWallet = new MockERC1271Wallet(agent1);

        vm.prank(address(mockWallet));
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        // Replace signerAddress in feedbackAuth with mockWallet address
        bytes memory authData = abi.encode(
            agentId,
            client1,
            uint64(5),
            block.timestamp + 1 hours,
            block.chainid,
            address(identityProxy),
            address(mockWallet)
        );
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(authData)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentOwnerKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        feedbackAuth = bytes.concat(authData, signature);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        assertEq(reputationRegistry.getLastIndex(agentId, client1), 1);
    }

    function testGetSummaryUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth1);

        address[] memory emptyClients = new address[](0);
        (uint64 count, uint8 avgScore) = reputationRegistry.getSummary(agentId, emptyClients, bytes32(0), bytes32(0));

        assertEq(count, 2);
        assertEq(avgScore, 85);
    }

    function testValidationSummaryUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash1 = keccak256("request1");
        bytes32 requestHash2 = keccak256("request2");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://r1", requestHash1);

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://r2", requestHash2);

        vm.prank(validator1);
        validationRegistry.validationResponse(requestHash1, 80, "ipfs://resp1", keccak256("d1"), bytes32(0));

        vm.prank(validator1);
        validationRegistry.validationResponse(requestHash2, 90, "ipfs://resp2", keccak256("d2"), bytes32(0));

        address[] memory emptyValidators = new address[](0);
        (uint64 count, uint8 avgResponse) = validationRegistry.getSummary(agentId, emptyValidators, bytes32(0));

        assertEq(count, 2);
        assertEq(avgResponse, 85);
    }

    function testRevokeFeedbackUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(client1);
        reputationRegistry.revokeFeedback(agentId, 1);

        (, , , bool isRevoked) = reputationRegistry.readFeedback(agentId, client1, 1);
        assertTrue(isRevoked);
    }

    function testAppendResponseUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(agent1);
        reputationRegistry.appendResponse(agentId, client1, 1, "ipfs://response", keccak256("r1"));

        address[] memory responders = new address[](1);
        responders[0] = agent1;
        uint64 count = reputationRegistry.getResponseCount(agentId, client1, 1, responders);
        assertEq(count, 1);
    }

    function testGetClientsUpgradeable() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        address[] memory clients = reputationRegistry.getClients(agentId);
        assertEq(clients.length, 1);
        assertEq(clients[0], client1);
    }

    // ============ Helper Functions ============

    function _createFeedbackAuth(
        uint256 agentId,
        address clientAddress,
        uint64 indexLimit,
        uint256 expiry,
        uint256 signerKey
    ) internal view returns (bytes memory) {
        address signerAddress = vm.addr(signerKey);

        bytes memory authData = abi.encode(
            agentId,
            clientAddress,
            indexLimit,
            expiry,
            block.chainid,
            address(identityProxy),
            signerAddress
        );

        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(authData)
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return bytes.concat(authData, signature);
    }
}
