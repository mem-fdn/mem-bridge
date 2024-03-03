export async function handle(state, action) {
	const input = action.input;

	if(input.function === "executeLock") {
		const { txid, caller, sig } = input;

		const req = (await EXM.deterministicFetch(`${state.mem_molecule}/${txid}/${caller}/${state.bridge_address}`))?.asJSON();
		ContractAssert(req.caller.toLowerCase() == caller.toLowerCase(), "err");
		ContractAssert(req.amount > 0,"err");
		state.balances[caller] += req.amount;

		return { state };
	}

	if (input.function === "initiateUnlock") {
		const {caller, sig, amount} = input;
		// validate caller, sig and amount, etc.
		ContractAssert(amount <= state.balances[caller],"err");

		state.unlocks.push({
			address: caller,
			mid: sig,
			amount: amount
		});

		state.balances[caller] -= amount;

		return { state };
	}
}