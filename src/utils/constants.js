export const BRIDGES_CONTRACTS = {
  "0x842b64bBA4D3bc5Cb29A7Bf73813a01CF684AF4a": {
    name: "usdc_token",
    decimals: 1e6,
  },
};

export const USDC_TOKEN_BRIDGE =
  "0x842b64bBA4D3bc5Cb29A7Bf73813a01CF684AF4a";
export const MEM_ORACLE_ID = `1dvxnlerOzF4hrFxlbOV57IHyrxSHMUTiMdtUNsWUgY`;
export const AO_PROCESS_ID = `oDMJXlSOhJ6UjH5i7Dl-UOr_dhS1rQCX4r9ws0jvFps`; // xtvzEpBJfkrKz8FRxwFUkP3q5x5OOWDn3LE6bkf0MT0

export const RPC_URL = `https://rpc.sepolia.org/`;

export const BRIDGE_ABI = [
  "function validateUnlock(string calldata _memid, address _caller) public returns (bytes32 requestId)",
];
