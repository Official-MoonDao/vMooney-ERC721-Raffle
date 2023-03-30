# vMooney Sweepstakes 🌕

This smart contract allows vMooney holders to enter a sweepstakes by minting an ERC-721 ticket. 
Holders can mint up to 1 ticket which cannot be transfered until the contract Owner enables "ticketTransfer".
Winners are selected by generating a random number using the Chainlink VRF and randomly selecting a token id.

## Deployment Guide

1. Pin metadata for ticket to IPFS, add it to the tokenURI function in the contract
2. Create a [Chainlink VRF](https://vrf.chain.link/)
3. Ensure that the LinkTokenInterface, keyHash and vrfCoordinator in the contract are correct. This will vary based on the network you would like to deploy to. [Supported Networks](https://docs.chain.link/vrf/v2/subscription/supported-networks) *(the vMooney contracts are currently deployed on Goerli and Mainnet)*
4. Deploy the vMooney Sweepstakes, then copy the contract address
5. Navigate to the Chainlink VRF you created in step 2 and add the vMooney Sweepstakes contract address as a "consumer" for your VRF
6. Copy the id of your VRF, set the id of the VRF in the vMooney Sweepstakes contract by using the "setSubscript" function
7. vMooney holders can now mint 1 ticket
8. When the sweepstakes comes to an end, pause the contract, and use the "chooseWinner" function to randomly select a winner.  Use the "winner" function to see the address of the winner.
(*Safeguard: verify that the winner has properly obtained the ticket throught the portal, double check the google-sheet used in the front-end and ensure that the holder's ticket is valid. If not, run the chooseWinner function again and select a new winner*)
9. (optional) After a winner has been chosen the contract owner can choose to allow holders to transfer their tickets, to enable ticket transfering use the "setTicketTransfer" function and pass in "true"