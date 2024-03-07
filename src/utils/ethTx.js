import { BRIDGES_CONTRACTS, RPC_URL } from "./constants.js";

import { ethers } from "ethers";
import assert from "node:assert";

export async function validateLock(txid, expectedCaller, tokenContractAddr) {
  try {
    const normalized = ethers.utils.getAddress;
    assert(tokenContractAddr in BRIDGES_CONTRACTS, true);
    // Set up provider for the Sepolia network
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
    const currentBlockNumber = await provider.getBlockNumber();

    const receipt = await provider.getTransactionReceipt(txid);
    console.log(receipt);
    const abi = ["event Lock (address target, uint256 amount)"];
    const iface = new ethers.utils.Interface(abi);

    const log = iface.parseLog(receipt.logs[2]);

    assert.equal(receipt.to, tokenContractAddr);
    assert.equal(normalized(receipt.from), normalized(expectedCaller));
    assert.equal(receipt.transactionHash, txid);
    assert.equal(Boolean(receipt.blockNumber), true);
    assert.equal(receipt.blockNumber + 3 < currentBlockNumber, true);
    const { args, name, signature } = log;
    assert.equal(signature, "Lock(address,uint256)");

    const target = args[0];
    // console.log(Number(ethers.utils.formatEther( args[1] )))
    const amount =
      Number(ethers.utils.formatEther(args[1])) *
      BRIDGES_CONTRACTS[tokenContractAddr]?.decimals;

    console.log({
      caller: target,
      amount,
      txid,
      tokenContractAddr,
    });
    return {
      caller: target,
      amount,
    };
  } catch (error) {
    console.error("Error:", error);
    return {
      sender: false,
    };
  }
}
