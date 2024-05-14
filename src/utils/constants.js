export const BRIDGES_CONTRACTS = {
  "0x783983f9265Fd9B816b22912F8dD750c2921EFdf": {
    name: "chainlink_token",
    decimals: 1e18,
  },
};

export const CHAINLINK_TOKEN_BRIDGE =
  "0x783983f9265Fd9B816b22912F8dD750c2921EFdf";
export const MEM_ORACLE_ID = `C4hsuvtitlF6I6a92BKteGX5AhjcWEKJB5jgESETI54`;
export const AO_PROCESS_ID = `xtvzEpBJfkrKz8FRxwFUkP3q5x5OOWDn3LE6bkf0MT0`;

export const RPC_URL = `https://rpc.sepolia.org/`;

export const BRIDGE_ABI = [
  "function validateUnlock(string calldata _memid, address _caller) public returns (bytes32 requestId)",
];
