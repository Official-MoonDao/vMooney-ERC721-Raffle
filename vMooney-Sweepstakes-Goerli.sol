/*
    NAME: TICKET-TO-ZERO-G 
    CHAIN: GOERLI
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
        LinkTokenInterface(0x326C977E6efc84E512bB9C30f76E30c160eD06FB); //https://vrf.chain.link/goerli
    bytes32 keyHash =
        0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15; //150gwei goerli
    address vrfCoordinator_ = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

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

    address public vMooneyAddress = 0x6899EcEeAF3Fb4D5854Dc090F62EA5D97E301664; //Goerli vMooney

    bool internal locked; //re-entry lock

    //EVENTS
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    constructor() VRFConsumerBaseV2(0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D) ERC721("TTZG Test", "TTZG") {
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
    