// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./lib/verifyIPFS.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

/**
 * THIS IS AN EXAMPLE CONTRACT WHICH USES HARDCODED VALUES FOR CLARITY.
 * PLEASE DO NOT USE THIS CODE IN PRODUCTION.
 */
contract APIConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
  
    // uint256 public volume;
    bytes32 private response1;
    bytes32 private response2;
    bytes32 private prefix;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    address private linkAddress;
    
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    constructor(bytes32 prefix_) {
        prefix = prefix_;

        linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        setChainlinkToken(linkAddress);
        oracle = 0xc8D925525CA8759812d0c299B90247917d4d4b7C;
        jobId = "a7330d0b4b964c05abc66a26307047c0";
        fee = 0.01 * 10 ** 18; // (Varies by network and job)
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestData() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        request.add("get", "https://lazy-nft.herokuapp.com/generate?tokenId=3");
        request.add("path", "chunks.0");
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function fulfill(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) returns (bytes32 requestId)
    {
        response1 = _response;
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.end.selector);
        request.add("get", "https://lazy-nft.herokuapp.com/generate?tokenId=3");
        request.add("path", "chunks.1");
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    function end(bytes32 _requestId, bytes32 _response) public recordChainlinkFulfillment(_requestId) {
        response2 = _response;
    }

    // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract
    function withdrawLink() external {
        // Withdraw the balance of LINK to the sender
        uint256 balance = IERC20(linkAddress).balanceOf(address(this));
        IERC20(linkAddress).transfer(msg.sender, balance);
    }

    function getParsedData() external view returns (string memory) {
        bytes memory encoded = verifyIPFS.toBase58(abi.encodePacked(prefix, response));
        return string(abi.encodePacked(encoded));
    }

    function getData() external view returns (bytes32, bytes32) {
        return response1, response2;
    }

    function getDataString() external view returns (string memory) {
        return string(abi.encodePacked(response));
    }
}