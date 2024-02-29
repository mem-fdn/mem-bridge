import { ethers } from 'ethers';
import { ABI } from "./abi.js";
import assert from "node:assert"

// console.log(ethers)

async function decodeTransactionLogs(txid, expectedCaller, tokenContractAddr) {
  try {
    // Set up provider for the Sepolia network
    const provider = new ethers.providers.JsonRpcProvider('https://1rpc.io/sepolia');


const receipt = await provider.getTransactionReceipt(txid);
let abi1 = [ "event Lock (address target, uint256 amount)" ];
let iface = new ethers.utils.Interface(abi1);

let log = iface.parseLog(receipt.logs[2]);

assert.equal(receipt.to, tokenContractAddr)
assert.equal(receipt.from,expectedCaller)
assert.equal(receipt.transactionHash, txid)
const {args, name, signature} = log
assert.equal(signature ,"Lock(address,uint256)")

const target = args[0];
const amount = ethers.utils.formatEther( args[1] );
// console.log(typeof target, amount)

console.log({
  sender: target,
  amount,
  txid,
  tokenContractAddr
})
return {
  sender: target,
  amount
}

  } catch (error) {
    console.error('Error:', error);
  }
}

// Call the function to decode transaction logs
// decodeTransactionLogs("0x47782cb1365e085957c8019e24edb79577236bd55d1fdb6e2b3a4f7d60f29d32", "0x197f818c1313DC58b32D88078ecdfB40EA822614", "0x650FC3477AfDFa14A595fb8E6715623Dc2d45FF1");

// https://sepolia.etherscan.io/tx/0x47782cb1365e085957c8019e24edb79577236bd55d1fdb6e2b3a4f7d60f29d32#eventlog

async function test(txid, expectedCaller, tokenContractAddr) {
  try {
    // Set up provider for the Sepolia network
    const provider = new ethers.providers.JsonRpcProvider('https://1rpc.io/sepolia');


const receipt = await provider.getTransactionReceipt(txid);
console.log(receipt.logs)
// let abi1 = [ "ChainlinkRequested (index_topic_1 bytes32 id)" ];
// let iface = new ethers.utils.Interface(abi1);

// // let log = iface.parseLog(receipt.logs[2]);
// console.log(logs)

// assert.equal(receipt.to, tokenContractAddr)
// assert.equal(receipt.from,expectedCaller)
// assert.equal(receipt.transactionHash, txid)
// const {args, name, signature} = log
// assert.equal(signature ,"Lock(address,uint256)")

// const target = args[0];
// const amount = ethers.utils.formatEther( args[1] );
// // console.log(typeof target, amount)

// console.log({
//   sender: target,
//   amount,
//   txid,
//   tokenContractAddr
// })
// return {
//   sender: target,
//   amount
// }

  } catch (error) {
    console.error('Error:', error);
  }
}

// Call the function to decode transaction logs
// decodeTransactionLogs("0x47782cb1365e085957c8019e24edb79577236bd55d1fdb6e2b3a4f7d60f29d32", "0x197f818c1313DC58b32D88078ecdfB40EA822614", "0x650FC3477AfDFa14A595fb8E6715623Dc2d45FF1");

test("0x959125a2bef1aaed85b5b2dfaa5be385a4f7c1150d21ff40a0c83324bacae183")