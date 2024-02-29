export async function handle(state, action) {
	const input = action.input;

	if (input.function === "issueUnlock") {
		const {caller, sig, amount} = input;
		// validate caller, sig and amount, etc.

		state.unlocks.push({
			address: caller,
			mid: sig,
			amount: amount
		});

		state.balances[caller] -= amount;

		return { state };
	}
}