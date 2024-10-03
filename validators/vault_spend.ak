use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, VerificationKeyHash, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{Lovelace, quantity_of}
use cardano/transaction.{Input}
use config
use types.{Control, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, filter_user_inputs,
  inputs_inline_datum, must_find_item,
}

pub type Transaction {
  inputs: List<Input>,
  reference_inputs: List<Input>,
  outputs: Data,
  fee: Data,
  mint: Data,
  certificates: Data,
  withdrawals: Pairs<Credential, Lovelace>,
  validity_range: Data,
  extra_signatories: List<VerificationKeyHash>,
  redeemers: Data,
  datums: Data,
  id: Data,
  votes: Data,
  proposal_procedures: Data,
  current_treasury_amount: Data,
  treasury_donation: Data,
}

validator vault_spend {
  withdraw(
    signatures: (ScriptHash, List<Signature>),
    _account: Credential,
    tx: Transaction,
  ) {
    let Transaction {
      inputs,
      reference_inputs,
      outputs,
      withdrawals,
      extra_signatories,
      ..
    } = tx

    let (user_stake, sigs) = signatures

    let expected_address =
      Address(Script(config.bullet_hash), Some(Inline(Script(user_stake))))

    expect Control { hot_cred, hot_cred_hash, .. } =
      reference_inputs
        |> must_find_item(
            fn(input) {
              input.output.value
                |> quantity_of(config.bullet_hash, user_stake)
                |> builtin.equals_integer(1)
            },
          )
        |> inputs_inline_datum()

    expect hot_cred_hash: List<Credential> = hot_cred_hash

    let inputs_spent = filter_user_inputs(inputs, expected_address)

    if hot_cred == dataify([]) {
      check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals)
    } else {
      expect hot_cred: List<Vk> = hot_cred

      let message =
        (inputs_spent, outputs)
          |> builtin.serialise_data()
          |> blake2b_256()

      check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals) && check_all_valid_vk_sigs(
        hot_cred,
        sigs,
        message,
      )
    }
  }

  else(_) {
    False
  }
}
