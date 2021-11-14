// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./lib/strings.sol";

contract Icons is Ownable, ERC1155, ChainlinkClient {
    using SafeMath for uint256;

    // Chainlink data
    address private oracle;
    bytes32 private jobId;
    uint256 linkFee;
    bytes32 private apiUrl;
    address private linkAddress;

    // Token data
    uint256 private immutable MINT_FEE_PER_TOKEN; 
    uint256 private immutable MAX_TOKENS; 
    uint256 private tokenId;

    // Store token mint requests
    mapping(address => uint256) private earlyMinters;
    uint256 private earlyMintEnd;

    struct MintRequest {
        uint256 initialTokenId;
        uint256 amount;
        address minter;
        bool fulfilled;
    }
    mapping(bytes32 => MintRequest) private mintRequests;

    constructor (uint256 mintFeePerToken_, uint256 maxTokens_, string memory uri_, uint256 earlyMintEnd_,
                address oracle_, bytes32 jobId_, uint256 linkFee_, bytes32 apiUrl_, address linkAddress_) ERC1155(uri_) {
        // Initialize contract data
        MINT_FEE_PER_TOKEN = mintFeePerToken_; 
        MAX_TOKENS = maxTokens_;
        earlyMintEnd = earlyMintEnd_;
        tokenId = 0;

        // Initialize chainlink data
        oracle = oracle_;
        jobId = jobId_;
        linkFee = linkFee_;
        apiUrl = apiUrl_;
        linkAddress = linkAddress_;
    }

    modifier mintable(uint256 _amount) {
        // Verify the tokens may be minted
        require(tokenId + _amount < MAX_TOKENS, "Icons: Tokens to mint exceeds max number of tokens");
        require(msg.value >= _amount.mul(MINT_FEE_PER_TOKEN) || _msgSender() == owner(), "Icons: Not enough funds to mint contract");
        _;
    }

    // Set the users early mint limit
    function earlyMintList(address _address, uint256 _amount) external onlyOwner {
        earlyMinters[_address] = _amount;
    }

    function earlyMint(uint256 _amount) external payable mintable(_amount) {
        // Mint the token if the user is approved and it is still in the early mint phase
        require(block.timestamp < earlyMintEnd, "Icons: Early minting phase is over, please use 'mint' instead");
        require(earlyMinters[_msgSender()] >= _amount, "Icons: You are not authorized to mint this amount of tokens");
        _mintIcon(_amount);
    }

    function mint(uint256 _amount) external payable mintable(_amount) {
        // Mint the token if it is after the early minting phase
        require(block.timestamp >= earlyMintEnd, "Icons: Contract is still in early minting phase, please use 'earlyMint' instead");
        _mintIcon(_amount);
    }

    function _mintIcon(uint256 _amount) {
        // Initialize the request
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        request.add("post", apiUrl);
        request.add("queryParams", abi.encode("tokenId=", tokenId, "&amount=", _amount));
        request.add("path", "URIs");

        // Update the new current token id
        bytes32 requestId = sendChainlinkRequestTo(oracle, request, linkFee);
        mintRequests[requestId] = MintRequest({
            initialTokenId: tokenId,
            amount: _amount,
            minter: _msgSender(),
            fulfilled: false
        });
        tokenId += _amount;
    }
    
    function fulfill(bytes32 _requestId, string memory _uri) external recordChainlinkFulfillment(_requestId) {
        // Require that the request has not already been fulfilled
        MintRequest memory request = mintRequests[_requestId];
        require(!request.fulfilled, "Icons: This request has already been fulfilled");

        // Split the string and add the items to the minters account
        strings.slice memory split = strings.toSlice(_uri);
        strings.slice memory delim = strings.toSlice(" ");
        for (uint i = 0; i < request.amount; i++) {
            string memory uri = strings.split(split, delim).toString();
            _mint(request.minter, request.initialTokenId + i, 1, uri);
        }

        // Update the fulfiled state
        mintRequests[_requestId].fulfilled = true;
    }

    function withdraw() external onlyOwner {
        // Withdraw the coins to the sender
        uint256 balance = address(this).balance;
        _msgSender().transfer(balance);
    }

    function withdrawLink() external onlyOwner {
        // Withdraw the balance of LINK to the sender
        uint256 balance = IERC20(linkAddress).balanceOf(address(this));
        IERC20.transfer(_msgSender(), balance);
    }
}