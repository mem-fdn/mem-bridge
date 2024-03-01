// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Staking is ChainlinkClient, ConfirmedOwner {
    using SafeERC20 for IERC20;
    using Chainlink for Chainlink.Request;

    IERC20 public immutable token;
    mapping(address => uint) public lastUpdated;
    mapping(address => uint) public balanceOf;
    mapping(bytes32 => uint256) public requests;
    mapping(bytes32 => string) public reqToMemId;
    mapping(string => bool) public midIsRedeemed;
    
    uint256 public volume;
    bool public result;
    bytes32 private jobId;
    uint256 private fee;
    uint public totalLocked = 0;
    
    event Lock(address address_, uint amount_);
    event Unlock(address address_, uint amount_);
    event RequestVolume(bytes32 indexed requestId, uint256 volume);
    event Request(bytes32 indexed requestId, uint256 result);

    constructor(IERC20 token_) ConfirmedOwner(msg.sender) {
        token = token_;
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "ca98366cc7314957b8c012c72f05aeeb"; // for uint256

        // c1c5e92880894eb6b27d3cae19670aa3 jobid for bool

        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function validateUnlock(string calldata memid) public returns (bytes32 requestId) {
        // bytes32 requestId;
        assert(!midIsRedeemed[memid]);
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        string memory arg1 = string.concat("https://test-mem-bridge-e73b7d9c5efe.herokuapp.com/validate-unlock/", memid);
        string memory caller = string.concat("/", Strings.toHexString(uint256(uint160(msg.sender)), 20));
        string memory url = string.concat(arg1, caller);



        // Set the URL to perform the GET request on
        req.add(
            "get",
            // "0xfb69a13dfec65b403838f6972fbdbdefdc87b3e0dff494ec1e27743d07ca52db601551d48710babad59d078ff57fdf0886e8847db30edf23f1998d9669e4f51d1c"
        url
        );

        req.add("path", "amount"); // Chainlink nodes 1.0.0 and later support this format

        req.addInt("times", 10**18);

        // Sends the request
        requestId = sendChainlinkRequest(req, fee);
        reqToMemId[requestId] = memid;
        midIsRedeemed[memid] = false;
        return requestId;
    }

    /**
     * Receive the response in the form of uint256
     */
    function fulfill(
        bytes32 _requestId,
        uint256 _result
    ) public recordChainlinkFulfillment(_requestId) returns (uint256) {
        string memory memid;
        assert(_result > 0);
        requests[_requestId] = _result;
        memid = reqToMemId[_requestId];
        require(!midIsRedeemed[memid], "err_mid_redeemed");
        emit Request(_requestId, _result);
        return _result;
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

function lock(uint amount_) external {
  token.safeTransferFrom(msg.sender, address(this), amount_);
  balanceOf[msg.sender] += amount_;
  // lastUpdated[msg.sender] = block.timestamp;
  totalLocked += amount_;
  emit Lock(msg.sender, amount_);
}
    

    function executeUnlock(bytes32 requestId_) public {
        uint256 amount_;
        string memory mid;
        amount_ = requests[requestId_];
        mid = reqToMemId[requestId_];
  require(balanceOf[msg.sender] >= amount_ && balanceOf[msg.sender] > 0, "Insufficient funds");
  midIsRedeemed[mid] = true;
  token.safeTransfer(msg.sender, amount_);
  balanceOf[msg.sender] -= amount_;
  totalLocked -= amount_;
  emit Unlock(msg.sender, amount_);
}
}

