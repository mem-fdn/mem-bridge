// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// migrated to call LinkWell chainlink node operator
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
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

    // chainlink jobId
    bytes32 private jobId;
    // chainlink oracle fee
    uint256 private oracleFee;
    // bridge fee hundredths of a percent
    uint256 private bridgeFee;
    // chainlink oracle address
    address private oracleAddress;
    // treasury EOA
    address private treasury;
    // stats: accumulated fees
    uint256 public cumulativeFees;
    // stats: total locked ERC20s
    uint256 public totalLocked;

    event Lock(address address_, uint256 amount_);
    event Unlock(address address_, uint256 amount_);
    event Request(bytes32 indexed requestId_, uint256 result_);

    constructor(
        IERC20 _btoken,
        address _oracleAddress,
        address _linkTokenAddr,
        address treasury_,
        string memory jobId_,
        uint256 _ofee,
        uint256 _bfee
    ) ConfirmedOwner(msg.sender) {
        token = _btoken; // 0x779877A7B0D9E8603169DdbD7836e478b4624789 $LINK
        treasury = treasury_; // 0x747D50C93e6821277805a2B80FE9CBF72EFCe6Cd
        setChainlinkToken(_linkTokenAddr); // 0x779877A7B0D9E8603169DdbD7836e478b4624789
        setChainlinkOracle(_oracleAddress); // 0x0FaCf846af22BCE1C7f88D1d55A038F27747eD2B
        setJobId(jobId_); // "a8356f48569c434eaa4ac5fcb4db5cc0"
        setFeeInHundredthsOfLink(_ofee); // sepolia is zero $LINK fee
        bridgeFee = _bfee; // 0.25% for the launch so uint256(25)
    }

    function validateUnlock(
        string calldata _memid
    ) public returns (bytes32 requestId) {
        // memid can be redeemed once
        assert(!midIsRedeemed[_memid]);
        // chainlink request
        Chainlink.Request memory req = buildOperatorRequest(
            jobId,
            this.fulfill.selector
        );

        // construct the API req full URL
        string memory arg1 = string.concat("https://0xmem.net/vu/", _memid);
        string memory caller = string.concat(
            "/",
            Strings.toHexString(uint256(uint160(msg.sender)), 20)
        );
        string memory url = string.concat(arg1, caller);

        // Set Chain req object
        req.add("method", "GET");
        req.add("url", url);
        req.add("path", "amount");
        req.add(
            "headers",
            '["content-type", "application/json", "set-cookie", "sid=14A52"]'
        );
        req.add("body", "");
        req.add("contact", "https://t.me/ + add later");
        req.addInt("multiplier", 1); // MEM store balances in uint256 as well

        // Sends the request
        requestId = sendOperatorRequest(req, oracleFee);
        // map requestId to caller
        reqToCaller[requestId] = msg.sender;
        // map the chainlink requestId to memid
        reqToMemId[requestId] = _memid;
        // map the memid redeeming status to false
        midIsRedeemed[_memid] = false;
        return requestId;
    }

    function fulfill(
        bytes32 _requestId,
        uint256 _result
    ) public recordChainlinkFulfillment(_requestId) returns (uint256) {
        string memory memid;
        // caller can't redeem memid with 0 amount
        require(_result > 0, "err_zero_amount");
        // retrieve the memid using the requestId and check its redeeming status
        memid = reqToMemId[_requestId];
        require(!midIsRedeemed[memid], "err_mid_redeemed");
        // map the chainlink request result to the corresponding requestId
        requests[_requestId] = _result;
        emit Request(_requestId, _result);
        return _result;
    }

    function lock(uint256 _amount) external {
        uint256 net_amount = computeNetAmount(_amount);
        uint256 generateFees = _amount - net_amount;
        // ERC20 token transfer
        token.safeTransferFrom(msg.sender, address(this), _amount);
        // update balances map
        balanceOf[msg.sender] += net_amount;
        // update treasury balance from fee cut
        balanceOf[treasury] += generateFees;
        // update totalLocked amount
        totalLocked += net_amount;
        //update treasury cumultive fee
        cumulativeFees += generateFees;
        // emit event
        emit Lock(msg.sender, net_amount);
    }

    function executeUnlock(bytes32 _requestId) public {
        // retrieve request amount and mem id from maps
        uint256 amount = requests[_requestId];
        string memory memid = reqToMemId[_requestId];
        // fee calculation
        uint256 net_amount = computeNetAmount(amount);
        uint256 generateFees = amount - net_amount;
        // validate that the request owner is the function caller
        require(reqToCaller[_requestId] == msg.sender, "err_invalid_caller");
        // do balances checks
        require(
            balanceOf[msg.sender] >= amount && balanceOf[msg.sender] > 0,
            "Insufficient funds"
        );
        // seal this memid and make its reusage not possible
        midIsRedeemed[memid] = true;
        // update the caller balance
        balanceOf[msg.sender] -= amount;
        // update the treasury balance
        balanceOf[treasury] += generateFees;
        // update stats: cumulative fees
        cumulativeFees += generateFees;
        // update stats: total locked tokens
        totalLocked -= net_amount;
        //transfer the tokens
        token.safeTransfer(msg.sender, net_amount);
        // emit event
        emit Unlock(msg.sender, net_amount);
    }

    function computeNetAmount(uint256 _amount) internal view returns (uint256) {
        uint256 bfee = (_amount * bridgeFee) / 10000;
        return _amount - bfee;
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

    // util functions

    // Update oracle address
    function setOracleAddress(address _oracleAddress) public onlyOwner {
        oracleAddress = _oracleAddress;
        setChainlinkOracle(_oracleAddress);
    }
    function getOracleAddress() public view onlyOwner returns (address) {
        return oracleAddress;
    }

    // Update jobId
    function setJobId(string memory _jobId) public onlyOwner {
        jobId = bytes32(bytes(_jobId));
    }

    function getJobId() public view onlyOwner returns (string memory) {
        return string(abi.encodePacked(jobId));
    }

    // Update fees
    function setFeeInJuels(uint256 _feeInJuels) public onlyOwner {
        oracleFee = _feeInJuels;
    }
    function setFeeInHundredthsOfLink(
        uint256 _feeInHundredthsOfLink
    ) public onlyOwner {
        setFeeInJuels((_feeInHundredthsOfLink * LINK_DIVISIBILITY) / 100);
    }
    function getFeeInHundredthsOfLink()
        public
        view
        onlyOwner
        returns (uint256)
    {
        return (oracleFee * 100) / LINK_DIVISIBILITY;
    }
}
