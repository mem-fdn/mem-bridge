import express from "express";
import bodyParser from "body-parser";
import cors from "cors";
import dotenv from "dotenv";
import axios from "axios";

import { validateUnlock } from "./utils/memTx.js";
import { validateLock } from "./utils/ethTx.js";
import { executeMemAoLock } from "./utils/aoMint.js";

dotenv.config();
const port = process.env.PORT || 3000;
const app = express();

app.use(
  cors({
    origin: "*",
  }),
);

app.use(bodyParser.json({ limit: "50mb" }));

app.use((err, req, res, next) => {
  res.status(500).send({ error: "invalid JSON input" });
  return;
});

// VU: Validate Unlock in the solidity `validateUnlock(string)` function
app.get("/vu/:mid/:caller", async (req, res) => {
  try {
    const { mid, caller } = req.params;
    const amount = await validateUnlock(mid, caller);
    res.json(amount); // unlock.amount
    return;
  } catch (error) {
    console.log(error);
    res.json({ amount: 0 });
    return;
  }
});

app.get("/vl/:txid/:caller/:bridgeAddr", async (req, res) => {
  try {
    const { txid, caller, bridgeAddr } = req.params;
    const result = await validateLock(txid, caller, bridgeAddr);
    res.json(result); // unlock.amount
    return;
  } catch (error) {
    console.log(error);
    res.json({ caller: null });
    return;
  }
});

// AL: execute the AO LOCK on MEM to AO
app.get("/al/:mid", async (req, res) => {
  try {
    const { mid } = req.params;
    const result = await executeMemAoLock(mid);
    res.json(result);
    return;
  } catch (error) {
    console.log(error);
    res.json({ messageId: null });
    return;
  }
});

app.listen(port);
