/*
    NAME: TICKET-TO-ZERO-G 
    CHAIN: MAINNET
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract vMooneySweeptstakes is ERC721, Ownable, Pausable, VRFConsumerBaseV2 {
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN =
        LinkTokenInterface(0x514910771AF9Ca656af840dff83E8264EcF986CA); //https://vrf.chain.link/mainnet
    bytes32 keyHash =
        0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef; //200gwei mainnet
    address vrfCoordinator_ = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;

   struct RequestStatus {
        bool paid; // paid?
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    address public winner;

    //VRF subscription ID.
    uint64 s_subscriptionId;

    uint256[] public requestIds;
    uint256 public lastRequestId;

    uint16 requestConfirmations = 6;
    uint32 numWords = 1;
    uint256 public maxTokens = 162; //gravitational pull of the moon (1.62 m/s^2)  
    bool public ticketTransfer = false;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    address public vMooneyAddress = 0xCc71C80d803381FD6Ee984FAff408f8501DB1740; //mainnet

    bool internal locked; //re-entry lock

    //EVENTS
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    constructor() VRFConsumerBaseV2(0x271682DEB8C4E0901D1a1550aD2e64D568E69909) ERC721("Ticket to Zero-G", "TTZG") {
          COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator_);
    }

    //MODIFIERS
    modifier reEntrancyGuard(){ 
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    //FUNCTIONS
    function setSubscript(uint64 subscriptionId_) external onlyOwner {
        s_subscriptionId = subscriptionId_;
    }

    function setTicketTransfer(bool ticketTransfer_) external onlyOwner {
        ticketTransfer = ticketTransfer_;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(_exists(tokenId), "URI query for nonexistent token");
        return "ipfs://"; //ticket metadata
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint() public reEntrancyGuard {
        (bool success, bytes memory result) = vMooneyAddress.call(abi.encodeWithSignature("locked__end(address)", msg.sender));
        require(abi.decode(result, (uint256)) > block.timestamp, "Wallet doesn't have vMooney");
        require(this.balanceOf(msg.sender) < 1, "Wallet already owns a ticket");
        uint256 tokenId = _tokenIdCounter.current();
        require(tokenId < maxTokens, "Tickets are sold out");
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        //non-transferable after mint until ticketTransfer = true
        if(from != address(0x0000000000000000000000000000000000000000) && !ticketTransfer) revert("Cannot transfer tickets until the winner is chosen");
    }

    function chooseWinner() external onlyOwner returns(uint256 requestId) {
        uint32 callbackGasLimit = 300000;
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            paid: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

     function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)
        internal
        override
    {
        require(s_requests[_requestId].paid, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        winner = this.ownerOf(_randomWords[0] % _tokenIdCounter.current());
        emit RequestFulfilled(_requestId, _randomWords);
    }

     function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (bool paid, bool fulfilled, uint256[] memory randomWords)
    {
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }
}
    