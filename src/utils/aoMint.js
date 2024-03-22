import { dryrun, createDataItemSigner, message } from "@permaweb/aoconnect";
import { AO_PROCESS_ID, MEM_ORACLE_ID } from "./constants.js";
import dotenv from "dotenv";
import axios from "axios";
import assert from "node:assert";

dotenv.config();

const wallet = JSON.parse(process.env.JWK);

export async function executeMemAoLock(id) {
  try {
    const memIdsInAo = await getMemIds();
    assert.equal(!memIdsInAo[id], true);
    const locks = (
      await axios.get(`https://api.mem.tech/api/state/${MEM_ORACLE_ID}`)
    )?.data?.aoLocks;

    const lockIndex = locks.findIndex((lock) => lock.id === id);
    assert.equal(lockIndex >= 0, true);
    const lock = locks[lockIndex];

    return await mintFor(lock.ao_address, id, lock.amount);
  } catch (error) {
    console.log(error);
    return false;
  }
}

async function mintFor(address, memId, qty) {
  try {
    const messageId = await message({
      process: AO_PROCESS_ID,
      signer: createDataItemSigner(wallet),
      data: "",
      tags: [
        { name: "Action", value: "Mint" },
        {
          name: "Address",
          value: address,
        },
        { name: "Quantity", value: qty },
        { name: "MemId", value: memId },
      ],
    });

    console.log(messageId);
    return { messageId };
  } catch (error) {
    console.log(error);
    return { messageId: false };
  }
}

async function getMemIds() {
  try {
    const tx = await dryrun({
      process: AO_PROCESS_ID,
      tags: [{ name: "Action", value: "GetMemIds" }],
    });

    return JSON.parse(tx.Messages[0].Data);
  } catch (error) {
    console.log(error);
    return {};
  }
}
