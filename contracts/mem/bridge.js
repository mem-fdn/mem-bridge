export async function handle(state, action) {
  const input = action.input;

  // lock on EVM, mint on MEM (EVM --> MEM)
  if (input.function === "executeLock") {
    // sig is not needed here as its already validated on EVM side
    // so without a sig,the dapp can invoke `executeLock`on behalf of user
    const { txid, caller } = input;
    const normalizedCaller = _normalizeCaller(caller);
    const req = (
      await EXM.deterministicFetch(
        `${state.mem_molecule}/${txid}/${normalizedCaller}/${state.bridge_address}`,
      )
    )?.asJSON();
    ContractAssert(req.caller.toLowerCase() == normalizedCaller, "err");
    ContractAssert(BigInt(req.amount) > 0n, "err");
    ContractAssert(
      !state.locks.includes(txid.toLowerCase()),
      "err_lock_already_redeemed",
    );
    state.locks.push(txid.toLowerCase());

    if (!(normalizedCaller in state.balances)) {
      state.balances[normalizedCaller] = BigInt(0).toString();
    }

    const newBalance =
      BigInt(state.balances[normalizedCaller]) + BigInt(req.amount);

    state.balances[normalizedCaller] = newBalance.toString();

    return { state };
  }
  // unlock on MEM, mint on EVM (MEM --> EVM)
  if (input.function === "initiateUnlock") {
    const { caller, sig, amount } = input;

    const bigIntAmount = BigInt(amount);

    ContractAssert(bigIntAmount > BigInt(state.evm_unlock_flatfee), "err_amount_too_low");

    const normalizedCaller = _normalizeCaller(caller);
    ContractAssert(
      bigIntAmount <= BigInt(state.balances[normalizedCaller]),
      "err",
    );

    await _moleculeSignatureVerification(normalizedCaller, sig);

    state.unlocks.push({
      address: normalizedCaller,
      mid: sig,
      amount: amount,
    });

    const newBalance = BigInt(state.balances[normalizedCaller]) - bigIntAmount;

    state.balances[normalizedCaller] = newBalance.toString();

    return { state };
  }

  // lock on MEM, mint on AO (MEM --> AO)
  if (input.function === "swapToAo") {
    const { caller, sig, ao_address, amount } = input;
    const normalizedCaller = _normalizeCaller(caller);
    const bigIntAmount = BigInt(amount);

    _validateArweaveAddress(ao_address);

    await _moleculeSignatureVerification(normalizedCaller, sig);

    ContractAssert(bigIntAmount > 0n, "err");
    ContractAssert(
      BigInt(state.balances[normalizedCaller]) >= bigIntAmount,
      "err_invalid_amount",
    );

    const newBalance = BigInt(state.balances[normalizedCaller]) - bigIntAmount;
    state.balances[normalizedCaller] = newBalance.toString();

    state.aoLocks.push({
      evm_caller: normalizedCaller,
      ao_address: ao_address,
      amount: bigIntAmount.toString(),
      id: sig,
    });

    return { state };
  }

  // lock on AO, mint on MEM (AO --> MEM)
  if (input.function === "executeUnlockFromAo") {
    const { caller, sig, auid } = input;

    ContractAssert(
      !state.aoUnlocks.includes(auid),
      "err_ao_unlock_id_already_used",
    );

    const normalizedCaller = _normalizeCaller(caller);
    await _moleculeSignatureVerification(normalizedCaller, sig);
    const moleculeArg = btoa(
      JSON.stringify([{ name: "Action", value: "GetBurnReqs" }]),
    );

    const aoUnlockIds = (
      await EXM.deterministicFetch(
        `${state.ao_molecule_endpoint}/${state.ao_process_id}/${moleculeArg}`,
      )
    )?.asJSON();

    ContractAssert(auid in aoUnlockIds, "err_aouid_not_found");

    const amount = BigInt(aoUnlockIds[auid].qty);
    const target = _normalizeCaller(aoUnlockIds[auid].mem_target);

    ContractAssert(target === normalizedCaller, "ERR_INVALID_CALLER");

    state.aoUnlocks.push(auid);

    if (!(normalizedCaller in state.balances)) {
      state.balances[normalizedCaller] = BigInt(0).toString();
    }

    const newBalance = BigInt(state.balances[normalizedCaller]) + amount;

    state.balances[normalizedCaller] = newBalance.toString();

    return { state };
  }
  // MEM <--> MEM
  if (input.function === "transfer") {
    const { caller, sig, target, amount } = input;

    const bigIntAmount = BigInt(amount);

    const normalizedCaller = _normalizeCaller(caller);
    const normalizedTarget = _normalizeCaller(target);

    ContractAssert(
      bigIntAmount <= BigInt(state.balances[normalizedCaller]),
      "err",
    );
    ContractAssert(normalizedCaller !== normalizedTarget, "err_self_transfer");

    await _moleculeSignatureVerification(normalizedCaller, sig);

    if (!(normalizedTarget in state.balances)) {
      state.balances[normalizedTarget] = BigInt(0n);
    }

    const newBalanceTarget =
      BigInt(state.balances[normalizedTarget]) + bigIntAmount;
    const newBalanceCaller =
      BigInt(state.balances[normalizedCaller]) - bigIntAmount;

    state.balances[normalizedTarget] = newBalanceTarget;
    state.balances[normalizedCaller] = newBalanceCaller;

    return { state };
  }

  if (input.function === "updateAdminStateProperty") {
    const { caller, key, sig, value } = input;

    const updateAbleKeys = [
      "bridge_address",
      "mem_molecule",
      "evm_molecule_endpoint",
      "ao_molecule_endpoint",
      "evm_unlock_flatfee",
      "sig_message",
      "ao_process_id",
      "name",
      "ticker"
    ];

    const normalizedCaller = _normalizeCaller(caller);
    ContractAssert(normalizedCaller === state.admin, "ERROR_INVALID_CALLER");
    ContractAssert(key in updateAbleKeys, "ERR_INVALID_UPDATEABLE_KEY");
    ContractAssert(
      typeof value === "string" && value.length,
      "ERROR_INVALID_UPDATEABLE_VALUE",
    );

    await _moleculeSignatureVerification(normalizedCaller, sig);

    state[key] = value;
    return { state };
  }

  async function _moleculeSignatureVerification(caller, signature) {
    try {
      ContractAssert(
        !state.signatures.includes(signature),
        "ERROR_SIGNATURE_ALREADY_USED",
      );

      const encodedMessage = btoa(`${state.sig_message}${state.counter}`);

      const isValid = await EXM.deterministicFetch(
        `${state.evm_molecule_endpoint}/signer/${caller}/${encodedMessage}/${signature}`,
      );
      ContractAssert(isValid.asJSON()?.result, "ERROR_UNAUTHORIZED_CALLER");
      state.signatures.push(signature);
      state.counter += 1;
    } catch (error) {
      throw new ContractError("ERROR_MOLECULE.SH_CONNECTION");
    }
  }

  function _validateEoaSyntax(address) {
    ContractAssert(
      /^(0x)?[0-9a-fA-F]{40}$/.test(address),
      "ERROR_INVALID_EOA_ADDR",
    );
  }

  function _validateArweaveAddress(address) {
    ContractAssert(
      /[a-z0-9_-]{43}/i.test(address),
      "ERROR_INVALID_ARWEAVE_ADDRESS",
    );
  }

  function _normalizeCaller(address) {
    _validateEoaSyntax(address);
    return address.toLowerCase();
  }
}
