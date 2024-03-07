// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// Imports
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {Chainlink, ChainlinkClient} from "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MemBridge contract
/// @notice crosschain ERC20 token bridge for MEM serverless functions
/// @dev Inherits from ERC20 for token functionality, Ownable for ownership management, and ChainlinkClient for oracle
/// @author charmful0x
/// @custom:security-contact darwin@decent.land

contract MemBridge is ChainlinkClient, ConfirmedOwner {
    using SafeERC20 for IERC20;
    using Chainlink for Chainlink.Request;

    IERC20 public immutable token;
    
    // Events declaration

    event Lock(address address_, uint256 amount_);
    event Unlock(address address_, uint256 amount_);
    event Request(bytes32 indexed requestId_, uint256 result_);

    // State variables declaration

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
    
    // Maps declaration

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

    /// @notice Constructor to initialize the MemBridge contract
    /// @param _btoken The address of the ERC20 token to bridge
    /// @param _oracleAddress The address of the chainlink node/oracle
    /// @param _linkTokenAddr The address of $LINK token on the contract deployed chain
    /// @param _treasury The address of the bridge's treasury that collects fees
    /// @param _jobId The oracle jobId
    /// @param _ofee The oracle $LINK fee
    /// @param _bfee The bridge service fee in hundredths of a percent
    constructor(
        IERC20 _btoken,
        address _oracleAddress,
        address _linkTokenAddr,
        address _treasury,
        string memory _jobId,
        uint256 _ofee,
        uint256 _bfee
    ) ConfirmedOwner(msg.sender) {
        token = _btoken; // 0x779877A7B0D9E8603169DdbD7836e478b4624789 $LINK
        treasury = _treasury; // 0x747D50C93e6821277805a2B80FE9CBF72EFCe6Cd
        setChainlinkToken(_linkTokenAddr); // 0x779877A7B0D9E8603169DdbD7836e478b4624789
        setChainlinkOracle(_oracleAddress); // 0x0FaCf846af22BCE1C7f88D1d55A038F27747eD2B
        setJobId(_jobId); // "a8356f48569c434eaa4ac5fcb4db5cc0"
        setFeeInHundredthsOfLink(_ofee); // sepolia is zero $LINK fee
        bridgeFee = _bfee; // 0.25% for the launch so uint256(25)
    }

    /// @notice The function that reads data from MEM partof the bridge
    /// @dev After issuing an unlock on MEM function, use the memid of that unlock req to fetch the unlockable amount
    /// This function send the request to the LinkWellNodes Chainlink's oracle and receive the amount that the user 
    /// can unlock for a given mem id.
    /// @param _memid The mem id of the issued unlock on the MEM serverless function
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
    /// @notice This function is called by the Chainlink oracle to resolve a request
    /// @dev The fulfill function is self-desriptive within the Chainlink usage context
    /// @param _requestId The oracle request ID
    /// @param _result The result of the requestId resolved by the oracle
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

    /// @notice The lock function allows the users to lock the _btoken bond to this contract
    /// @dev Lock _btoken to the caller's address
    /// @param _amount The amount of tokens to lock 
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

    /// @notice This function is called after the validatUnlock() using the requestId of the memid
    /// @dev After calling validateUnlock() and mapping the requestId to amount, and requestId to memid,
    /// grab the requestId and call this function to finalize the TX lifecycle of a balance unlock action
    /// @param _requestId The requestId mapping the amount of tokens to unlock
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
    /// @notice Calculate the net amount upon lock or unlock
    /// @param _amount the lock/unlock amount (from requestId)
    function computeNetAmount(uint256 _amount) internal view returns (uint256) {
        uint256 bfee = (_amount * bridgeFee) / 10000;
        return _amount - bfee;
    }

    /// @notice Withdraw all of the $LINK token held by the contract (which is used to cover
    /// the oracle calls fees)
    /// @dev This function is called only by the contract owner
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
    
    /// @notice Withdraw the bridging service fees generated by contract usage
    /// to the treasury EOA.
    /// @dev Can be only called by the treasury EOA 
    function withdrawFees() public {
        uint256 amount = balanceOf[treasury];
        assert(amount > 0);
        require(msg.sender == treasury, "err_invalid_caller");
        token.safeTransfer(treasury, amount);
        balanceOf[treasury] = 0;
    }

    /**
        Util Functions
    */

    /// @notice Update oracle address
    /// @dev Can be only called by contract owner
    /// @param _oracleAddress The new oracle address
    function setOracleAddress(address _oracleAddress) public onlyOwner {
        oracleAddress = _oracleAddress;
        setChainlinkOracle(_oracleAddress);
    }

    /// @notice retrieve currently in-use oracle address
    /// @dev Can be only called by contract owner
    function getOracleAddress() public view onlyOwner returns (address) {
        return oracleAddress;
    }

    /// @notice Update oracle's jobId
    /// @dev Can be only called by contract owner
    /// @param _jobId The jobId string identifier
    function setJobId(string memory _jobId) public onlyOwner {
        jobId = bytes32(bytes(_jobId));
    }

    /// @notice Retrieve currently in-use jobId
    /// @dev Can be only called by contract owner
    function getJobId() public view onlyOwner returns (string memory) {
        return string(abi.encodePacked(jobId));
    }

    /// @notice Update oracle's fee variable
    /// @dev Can be only called by contract owner
    /// @param _feeInJuels Fees in Juels
    function setFeeInJuels(uint256 _feeInJuels) public onlyOwner {
        oracleFee = _feeInJuels;
    }

    /// @notice Update oracle's fee variable
    /// @dev Can be only called by contract owner. This function
    /// is the main used function in the oracle's setup within
    /// this contract.
    /// @param _feeInHundredthsOfLink Fees in hundredth of $LINK (18 decimals)
    function setFeeInHundredthsOfLink(
        uint256 _feeInHundredthsOfLink
    ) public onlyOwner {
        setFeeInJuels((_feeInHundredthsOfLink * LINK_DIVISIBILITY) / 100);
    }

    /// @notice Get the oracleFee state variable fee value
    /// @dev Only called by contract owner
    function getFeeInHundredthsOfLink()
        public
        view
        onlyOwner
        returns (uint256)
    {
        return (oracleFee * 100) / LINK_DIVISIBILITY;
    }
}
