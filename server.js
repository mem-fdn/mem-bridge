import express from "express";
import bodyParser from "body-parser";
import cors from "cors";
import dotenv from "dotenv";
import axios from "axios";

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

app.get("/validate-unlock/:mid/:caller", async (req, res) => {
  try {
    const { mid, caller } = req.params;
    const contractState = (await axios.get(`https://api.mem.tech/api/state/djTS6Uh1Id6bAJXkIubAQwrR0ERzCgYdmlLAy28Blag`))?.data?.unlocks;
    const unlock = contractState.find((req) => req.mid === mid && req.address.toLowerCase() == caller.toLowerCase());
    res.json({amount: 1995000000000000000}); // unlock.amount
    return;

    return;
  } catch (error) {
    console.log(error)
    res.json({ status: "error" });
    return;
  }
});

app.listen(port);