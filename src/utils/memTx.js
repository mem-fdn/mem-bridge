import axios from "axios";
import { ethers } from "ethers";
import {
  MEM_ORACLE_ID,
  CHAINLINK_TOKEN_BRIDGE,
  BRIDGE_ABI,
  RPC_URL,
} from "./constants.js";
import { getRequestIdFromTxid } from "./ethTx.js";
import dotenv from "dotenv";

dotenv.config();

export async function validateUnlock(memid, caller) {
  try {
    const normalized = ethers.utils.getAddress;
    const contractState = (
      await axios.get(`https://api.mem.tech/api/state/${MEM_ORACLE_ID}`)
    )?.data?.unlocks;
    const unlock = contractState.find(
      (req) =>
        req.mid === memid && normalized(req.address) == normalized(caller),
    );
    return { amount: Number(unlock.amount) };
  } catch (error) {
    console.log(error);
    return { amount: 0 };
  }
}

async function getMemIssuedUnlocks(memid, caller) {
  try {
    const normalized = ethers.utils.getAddress;
    const contractState = (
      await axios.get(`https://api.mem.tech/api/state/${MEM_ORACLE_ID}`)
    )?.data?.unlocks;
    const unlock = contractState.find(
      (req) =>
        req.mid === memid && normalized(req.address) == normalized(caller),
    );
    return unlock;
  } catch (error) {
    console.log(error);
    return {};
  }
}

export async function callEvmValidateUnlock(memid, caller) {
  try {
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
    const signer = new ethers.Wallet(process.env.CRONJOB_PK, provider);
    const BridgeContract = new ethers.Contract(
      CHAINLINK_TOKEN_BRIDGE,
      BRIDGE_ABI,
      signer,
    );

    const tx = await BridgeContract.validateUnlock(memid, caller);
    await tx.wait();
    const requestId = await getRequestIdFromTxid(tx.hash);
    return { requestId };
  } catch (error) {
    console.log(error);
    return { requestId: null };
  }
}
