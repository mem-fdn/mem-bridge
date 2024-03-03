// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MemBridge is ChainlinkClient, ConfirmedOwner {
    using SafeERC20 for IERC20;
    using Chainlink for Chainlink.Request;

    IERC20 public immutable token;
    // locked ERC20 balances
    mapping(address => uint) public balanceOf;
    // unlocking requests amount (result)
    mapping(bytes32 => uint256) public requests;
    // mapping unlockIds to MEM IDs
    mapping(bytes32 => string) public reqToMemId;
    // mapping MEM ID to its redeeming status
    mapping(string => bool) public midIsRedeemed;
    // map requestId to caller
    mapping(bytes32 => address) public reqToCaller;

    // uint256 public volume;
    bool public result;
    bytes32 private jobId;
    uint256 private fee;
    uint public totalLocked = 0;
    address public treasury = 0x747D50C93e6821277805a2B80FE9CBF72EFCe6Cd;
    uint256 public cumulativeFees;

    event Lock(address address_, uint256 amount_);
    event Unlock(address address_, uint256 amount_);
    event Request(bytes32 indexed requestId_, uint256 result_);

    constructor(IERC20 token_) ConfirmedOwner(msg.sender) {
        token = token_;
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function validateUnlock(
        string calldata memid
    ) public returns (bytes32 requestId) {
        // memid can be redeemed once
        assert(!midIsRedeemed[memid]);
        // chainlink request
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );
        // construct the API req full URL
        string memory arg1 = string.concat(
            "https://test-mem-bridge-e73b7d9c5efe.herokuapp.com/vu/",
            memid
        );
        string memory caller = string.concat(
            "/",
            Strings.toHexString(uint256(uint160(msg.sender)), 20)
        );
        string memory url = string.concat(arg1, caller);

        // Set Chain req object
        req.add("get", url);
        req.add("path", "amount");
        req.addInt("times", 1);

        // Sends the request
        requestId = sendChainlinkRequest(req, fee);
        // map requestId to caller
        reqToCaller[requestId] = msg.sender;
        // map the chainlink requestId to memid
        reqToMemId[requestId] = memid;
        // map the memid redeeming status to false
        midIsRedeemed[memid] = false;
        return requestId;
    }

    function fulfill(
        bytes32 _requestId,
        uint256 _result
    ) public recordChainlinkFulfillment(_requestId) returns (uint256) {
        string memory memid;
        // caller can't redeem memid with 0 amount
        assert(_result > 0);
        // map the chainlink request result to the corresponding requestId
        requests[_requestId] = _result;
        // retrieve the memid using the requestId and check its redeeming status
        memid = reqToMemId[_requestId];
        require(!midIsRedeemed[memid], "err_mid_redeemed");
        emit Request(_requestId, _result);
        return _result;
    }

    function lock(uint256 amount_) external {
        // declare a 0.25% fee
        fee = (amount_ * 25) / 10000;
        // ERC20 token transfer
        token.safeTransferFrom(msg.sender, address(this), amount_);
        // update balances map
        balanceOf[msg.sender] += amount_ - fee;
        // update treasury balance from fee cut
        balanceOf[treasury] += fee;
        // update totalLocked amount
        totalLocked += amount_ - fee;
        //update treasury cumultive fee
        cumulativeFees += fee;
        emit Lock(msg.sender, amount_ - fee);
    }

    function executeUnlock(bytes32 requestId_) public {
        uint256 amount_;
        uint256 net_amount;
        string memory memid;

        amount_ = requests[requestId_];
        memid = reqToMemId[requestId_];

        fee = (amount_ * 25) / 10000;
        net_amount = amount_ - fee;

        require(reqToCaller[requestId_] == msg.sender, "err_invalid_caller");
        require(
            balanceOf[msg.sender] >= amount_ && balanceOf[msg.sender] > 0,
            "Insufficient funds"
        );

        midIsRedeemed[memid] = true;
        token.safeTransfer(msg.sender, net_amount);
        balanceOf[msg.sender] -= amount_;
        balanceOf[treasury] += fee;
        cumulativeFees += fee;
        totalLocked -= net_amount;
        emit Unlock(msg.sender, net_amount);
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

    function withdrawFees() public {
        uint256 amount = balanceOf[treasury];
        assert(amount > 0);
        require(msg.sender == treasury, "err_invalid_caller");
        token.safeTransfer(treasury, amount);
        balanceOf[treasury] = 0;
    }
}