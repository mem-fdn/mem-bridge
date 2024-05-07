export const BRIDGES_CONTRACTS = {
  "0xe1225ecbBDAB62Eba6F2Bc4366B7A6943F07A5e0": {
    name: "chainlink_token",
    decimals: 1e18,
  },
};

export const CHAINLINK_TOKEN_BRIDGE =
  "0xe1225ecbBDAB62Eba6F2Bc4366B7A6943F07A5e0";
export const MEM_ORACLE_ID = `Bali0mqkkep3dqThT-DRPCn4EbwZc4YLVumvKyG9N4I`;
export const AO_PROCESS_ID = `xtvzEpBJfkrKz8FRxwFUkP3q5x5OOWDn3LE6bkf0MT0`;

export const RPC_URL = `https://1rpc.io/sepolia`;

export const BRIDGE_ABI = [
  "function validateUnlock(string calldata _memid, address _caller) public returns (bytes32 requestId)",
];
