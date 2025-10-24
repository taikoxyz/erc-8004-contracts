// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/IdentityRegistry.sol";
import "../src/ReputationRegistry.sol";
import "../src/ValidationRegistry.sol";
import "../src/MockERC1271Wallet.sol";

contract ERC8004Test is Test {
    IdentityRegistry public identityRegistry;
    ReputationRegistry public reputationRegistry;
    ValidationRegistry public validationRegistry;
    MockERC1271Wallet public mockWallet;

    address public owner;
    address public agent1;
    address public agent2;
    address public client1;
    address public client2;
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
        agent2 = address(0x2);
        client2 = address(0x3);
        validator1 = address(0x4);

        identityRegistry = new IdentityRegistry();
        reputationRegistry = new ReputationRegistry(address(identityRegistry));
        validationRegistry = new ValidationRegistry(address(identityRegistry));
    }

    // ============ IdentityRegistry Tests ============

    function testRegisterWithoutUri() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();
        assertEq(agentId, 0);
        assertEq(identityRegistry.ownerOf(agentId), agent1);
        assertEq(identityRegistry.tokenURI(agentId), "");
    }

    function testRegisterWithUri() public {
        string memory uri = "ipfs://QmTest";
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register(uri);
        assertEq(agentId, 0);
        assertEq(identityRegistry.ownerOf(agentId), agent1);
        assertEq(identityRegistry.tokenURI(agentId), uri);
    }

    function testRegisterWithMetadata() public {
        string memory uri = "ipfs://QmTest";
        IdentityRegistry.MetadataEntry[] memory metadata = new IdentityRegistry.MetadataEntry[](2);
        metadata[0] = IdentityRegistry.MetadataEntry("name", bytes("Agent1"));
        metadata[1] = IdentityRegistry.MetadataEntry("version", bytes("1.0"));

        vm.prank(agent1);
        uint256 agentId = identityRegistry.register(uri, metadata);

        assertEq(agentId, 0);
        assertEq(identityRegistry.getMetadata(agentId, "name"), bytes("Agent1"));
        assertEq(identityRegistry.getMetadata(agentId, "version"), bytes("1.0"));
    }

    function testSetMetadataByOwner() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setMetadata(agentId, "name", bytes("UpdatedName"));
        assertEq(identityRegistry.getMetadata(agentId, "name"), bytes("UpdatedName"));
    }

    function testSetMetadataByOperator() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setApprovalForAll(operator1, true);

        vm.prank(operator1);
        identityRegistry.setMetadata(agentId, "name", bytes("OperatorSet"));
        assertEq(identityRegistry.getMetadata(agentId, "name"), bytes("OperatorSet"));
    }

    function testSetMetadataByApproved() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.approve(operator1, agentId);

        vm.prank(operator1);
        identityRegistry.setMetadata(agentId, "name", bytes("ApprovedSet"));
        assertEq(identityRegistry.getMetadata(agentId, "name"), bytes("ApprovedSet"));
    }

    function testRevertSetMetadataUnauthorized() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(client1);
        vm.expectRevert("Not authorized");
        identityRegistry.setMetadata(agentId, "name", bytes("Unauthorized"));
    }

    function testSetAgentUriByOwner() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register("ipfs://old");

        vm.prank(agent1);
        identityRegistry.setAgentUri(agentId, "ipfs://new");
        assertEq(identityRegistry.tokenURI(agentId), "ipfs://new");
    }

    function testSetAgentUriByOperator() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register("ipfs://old");

        vm.prank(agent1);
        identityRegistry.setApprovalForAll(operator1, true);

        vm.prank(operator1);
        identityRegistry.setAgentUri(agentId, "ipfs://operator");
        assertEq(identityRegistry.tokenURI(agentId), "ipfs://operator");
    }

    function testRevertSetAgentUriUnauthorized() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register("ipfs://old");

        vm.prank(client1);
        vm.expectRevert("Not authorized");
        identityRegistry.setAgentUri(agentId, "ipfs://unauthorized");
    }

    // ============ ReputationRegistry Tests ============

    function testGiveFeedback() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(
            agentId,
            85,
            keccak256("quality"),
            keccak256("fast"),
            "ipfs://feedback1",
            keccak256("feedbackdata"),
            feedbackAuth
        );

        (uint8 score, bytes32 tag1, bytes32 tag2, bool isRevoked) = reputationRegistry.readFeedback(agentId, client1, 1);
        assertEq(score, 85);
        assertEq(tag1, keccak256("quality"));
        assertEq(tag2, keccak256("fast"));
        assertFalse(isRevoked);
    }

    function testRejectFeedbackFromAgentOwner() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, agent1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(agent1);
        vm.expectRevert("Self-feedback not allowed");
        reputationRegistry.giveFeedback(
            agentId,
            85,
            keccak256("quality"),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );
    }

    function testRejectFeedbackFromOperator() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setApprovalForAll(operator1, true);

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, operator1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(operator1);
        vm.expectRevert("Self-feedback not allowed");
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );
    }

    function testRejectFeedbackFromApproved() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.approve(operator1, agentId);

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, operator1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(operator1);
        vm.expectRevert("Self-feedback not allowed");
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );
    }

    function testRejectInvalidFeedbackSignature() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, client1Key);

        vm.prank(client1);
        vm.expectRevert("Signer not authorized");
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );
    }

    function testRejectExpiredFeedbackAuth() public {
        vm.warp(10000);

        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp - 1, agentOwnerKey);

        vm.prank(client1);
        vm.expectRevert("Auth expired");
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );
    }

    function testRejectFeedbackExceedingIndexLimit() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 1, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback1",
            keccak256("data1"),
            feedbackAuth
        );

        vm.prank(client1);
        vm.expectRevert("IndexLimit exceeded");
        reputationRegistry.giveFeedback(
            agentId,
            90,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback2",
            keccak256("data2"),
            feedbackAuth
        );
    }

    function testOperatorCanSignFeedbackAuth() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setApprovalForAll(operator1, true);

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, operatorKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );

        assertEq(reputationRegistry.getLastIndex(agentId, client1), 1);
    }

    function testERC1271WalletCanSignFeedbackAuth() public {
        mockWallet = new MockERC1271Wallet(agent1);

        vm.prank(address(mockWallet));
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        // Replace signerAddress in feedbackAuth with mockWallet address
        bytes memory authData = abi.encode(agentId, client1, uint64(5), block.timestamp + 1 hours, block.chainid, address(identityRegistry), address(mockWallet));
        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(authData)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentOwnerKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        feedbackAuth = bytes.concat(authData, signature);

        vm.prank(client1);
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );

        assertEq(reputationRegistry.getLastIndex(agentId, client1), 1);
    }

    function testRevokeFeedback() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );

        vm.prank(client1);
        reputationRegistry.revokeFeedback(agentId, 1);

        (, , , bool isRevoked) = reputationRegistry.readFeedback(agentId, client1, 1);
        assertTrue(isRevoked);
    }

    function testAppendResponse() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(
            agentId,
            85,
            bytes32(0),
            bytes32(0),
            "ipfs://feedback",
            keccak256("data"),
            feedbackAuth
        );

        vm.prank(agent1);
        reputationRegistry.appendResponse(agentId, client1, 1, "ipfs://response", keccak256("response"));

        address[] memory responders = new address[](1);
        responders[0] = agent1;
        uint64 count = reputationRegistry.getResponseCount(agentId, client1, 1, responders);
        assertEq(count, 1);
    }

    function testGetSummary() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);
        bytes memory feedbackAuth2 = _createFeedbackAuth(agentId, client2, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth2);

        address[] memory emptyClients = new address[](0);
        (uint64 count, uint8 avgScore) = reputationRegistry.getSummary(agentId, emptyClients, bytes32(0), bytes32(0));

        assertEq(count, 2);
        assertEq(avgScore, 85);
    }

    function testGetSummaryWithTags() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 qualityTag = keccak256("quality");
        bytes32 speedTag = keccak256("speed");

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);
        bytes memory feedbackAuth2 = _createFeedbackAuth(agentId, client2, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, qualityTag, bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 90, speedTag, bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth2);

        address[] memory emptyClients = new address[](0);
        (uint64 count, uint8 avgScore) = reputationRegistry.getSummary(agentId, emptyClients, qualityTag, bytes32(0));

        assertEq(count, 1);
        assertEq(avgScore, 80);
    }

    function testReadAllFeedback() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);
        bytes memory feedbackAuth2 = _createFeedbackAuth(agentId, client2, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth2);

        address[] memory emptyClients = new address[](0);
        (address[] memory clients, uint8[] memory scores, , , bool[] memory revoked) =
            reputationRegistry.readAllFeedback(agentId, emptyClients, bytes32(0), bytes32(0), false);

        assertEq(clients.length, 2);
        assertEq(scores[0], 80);
        assertEq(scores[1], 90);
        assertFalse(revoked[0]);
        assertFalse(revoked[1]);
    }

    function testGetResponseCountMultiple() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(agent1);
        reputationRegistry.appendResponse(agentId, client1, 1, "ipfs://r1", keccak256("r1"));

        vm.prank(agent1);
        reputationRegistry.appendResponse(agentId, client1, 1, "ipfs://r2", keccak256("r2"));

        address[] memory emptyResponders = new address[](0);
        uint64 count = reputationRegistry.getResponseCount(agentId, client1, 1, emptyResponders);
        assertEq(count, 2);
    }

    function testGetClients() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);
        bytes memory feedbackAuth2 = _createFeedbackAuth(agentId, client2, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth2);

        address[] memory clients = reputationRegistry.getClients(agentId);
        assertEq(clients.length, 2);
        assertEq(clients[0], client1);
        assertEq(clients[1], client2);
    }

    // ============ ValidationRegistry Tests ============

    function testValidationRequest() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        (address validator, uint256 returnedAgentId, uint8 response, , , ) =
            validationRegistry.getValidationStatus(requestHash);

        assertEq(validator, validator1);
        assertEq(returnedAgentId, agentId);
        assertEq(response, 0);
    }

    function testValidationRequestByOperator() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(agent1);
        identityRegistry.setApprovalForAll(operator1, true);

        bytes32 requestHash = keccak256("request1");

        vm.prank(operator1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        (address validator, , , , , ) = validationRegistry.getValidationStatus(requestHash);
        assertEq(validator, validator1);
    }

    function testRevertValidationRequestUnauthorized() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(client1);
        vm.expectRevert("Not authorized");
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);
    }

    function testValidationResponse() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        vm.prank(validator1);
        validationRegistry.validationResponse(requestHash, 95, "ipfs://response", keccak256("responsedata"), keccak256("tag"));

        (, , uint8 response, bytes32 responseHash, bytes32 tag, ) =
            validationRegistry.getValidationStatus(requestHash);

        assertEq(response, 95);
        assertEq(responseHash, keccak256("responsedata"));
        assertEq(tag, keccak256("tag"));
    }

    function testRevertValidationResponseUnauthorized() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        vm.prank(client1);
        vm.expectRevert("not validator");
        validationRegistry.validationResponse(requestHash, 95, "ipfs://response", keccak256("data"), keccak256("tag"));
    }

    function testGetValidationSummary() public {
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

    function testGetAgentValidations() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash1 = keccak256("request1");
        bytes32 requestHash2 = keccak256("request2");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://r1", requestHash1);

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://r2", requestHash2);

        bytes32[] memory validations = validationRegistry.getAgentValidations(agentId);
        assertEq(validations.length, 2);
        assertEq(validations[0], requestHash1);
        assertEq(validations[1], requestHash2);
    }

    function testGetValidatorRequests() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        bytes32[] memory requests = validationRegistry.getValidatorRequests(validator1);
        assertEq(requests.length, 1);
        assertEq(requests[0], requestHash);
    }

    function testMultipleFeedbackFromSameClient() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth);

        assertEq(reputationRegistry.getLastIndex(agentId, client1), 2);
    }

    function testResponsesFromMultipleResponders() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(agent1);
        reputationRegistry.appendResponse(agentId, client1, 1, "ipfs://r1", keccak256("r1"));

        vm.prank(client2);
        reputationRegistry.appendResponse(agentId, client1, 1, "ipfs://r2", keccak256("r2"));

        address[] memory emptyResponders = new address[](0);
        uint64 count = reputationRegistry.getResponseCount(agentId, client1, 1, emptyResponders);
        assertEq(count, 2);
    }

    function testRevertAppendResponseEmptyUri() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(agent1);
        vm.expectRevert("Empty URI");
        reputationRegistry.appendResponse(agentId, client1, 1, "", keccak256("r1"));
    }

    function testRevertRevokeFeedbackIndexZero() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(client1);
        vm.expectRevert("index must be > 0");
        reputationRegistry.revokeFeedback(agentId, 0);
    }

    function testRevertRevokeFeedbackOutOfBounds() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        vm.prank(client1);
        vm.expectRevert("index out of bounds");
        reputationRegistry.revokeFeedback(agentId, 1);
    }

    function testRevertRevokeAlreadyRevoked() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);

        vm.prank(client1);
        reputationRegistry.revokeFeedback(agentId, 1);

        vm.prank(client1);
        vm.expectRevert("Already revoked");
        reputationRegistry.revokeFeedback(agentId, 1);
    }

    function testRevertGiveFeedbackToNonexistentAgent() public {
        bytes memory feedbackAuth = _createFeedbackAuth(999, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        vm.expectRevert("Agent does not exist");
        reputationRegistry.giveFeedback(999, 85, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);
    }

    function testRevertGiveFeedbackInvalidScore() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        vm.expectRevert("score>100");
        reputationRegistry.giveFeedback(agentId, 101, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth);
    }

    function testRevertValidationResponseInvalidScore() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes32 requestHash = keccak256("request1");

        vm.prank(agent1);
        validationRegistry.validationRequest(validator1, agentId, "ipfs://request", requestHash);

        vm.prank(validator1);
        vm.expectRevert("resp>100");
        validationRegistry.validationResponse(requestHash, 101, "ipfs://response", keccak256("data"), keccak256("tag"));
    }

    function testGetSummaryExcludesRevokedFeedback() public {
        vm.prank(agent1);
        uint256 agentId = identityRegistry.register();

        bytes memory feedbackAuth1 = _createFeedbackAuth(agentId, client1, 5, block.timestamp + 1 hours, agentOwnerKey);
        bytes memory feedbackAuth2 = _createFeedbackAuth(agentId, client2, 5, block.timestamp + 1 hours, agentOwnerKey);

        vm.prank(client1);
        reputationRegistry.giveFeedback(agentId, 80, bytes32(0), bytes32(0), "ipfs://f1", keccak256("d1"), feedbackAuth1);

        vm.prank(client2);
        reputationRegistry.giveFeedback(agentId, 90, bytes32(0), bytes32(0), "ipfs://f2", keccak256("d2"), feedbackAuth2);

        vm.prank(client1);
        reputationRegistry.revokeFeedback(agentId, 1);

        address[] memory emptyClients = new address[](0);
        (uint64 count, uint8 avgScore) = reputationRegistry.getSummary(agentId, emptyClients, bytes32(0), bytes32(0));

        assertEq(count, 1);
        assertEq(avgScore, 90);
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
            address(identityRegistry),
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
