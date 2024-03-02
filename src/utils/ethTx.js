import { BRIDGES_CONTRACTS } from "./constants.js";

import { ethers } from 'ethers';
import assert from "node:assert"


export async function validateLock(txid, expectedCaller, tokenContractAddr) {
  try {
    assert(tokenContractAddr in BRIDGES_CONTRACTS, true);
    // Set up provider for the Sepolia network
    const provider = new ethers.providers.JsonRpcProvider('https://1rpc.io/sepolia');


const receipt = await provider.getTransactionReceipt(txid);
let abi1 = [ "event Lock (address target, uint256 amount)" ];
let iface = new ethers.utils.Interface(abi1);

let log = iface.parseLog(receipt.logs[2]);

assert.equal(receipt.to, tokenContractAddr)
assert.equal(receipt.from, expectedCaller)
assert.equal(receipt.transactionHash, txid)
const {args, name, signature} = log
assert.equal(signature ,"Lock(address,uint256)")

const target = args[0];
const amount = Number(ethers.utils.formatEther( args[1] )) * BRIDGES_CONTRACTS[tokenContractAddr]?.decimals;

console.log({
  caller: target,
  amount,
  txid,
  tokenContractAddr
})
return {
  caller: target,
  amount
}

  } catch (error) {
    console.error('Error:', error);
    return {
      sender: false
    }
    
  }
}


// Call the function to decode transaction logs
// decodeTransactionLogs("0x37b04fabd2dccb71e9aa76e6986703f00f280fd974e47340bc92c91b3909409c", "0x197f818c1313DC58b32D88078ecdfB40EA822614", "0x67C7DA15C8855AfceDc7258469dF7180058C1100");

