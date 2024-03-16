import axios from "axios";
import { ethers } from "ethers";
import { MEM_ORACLE_ID } from "./constants.js";

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
