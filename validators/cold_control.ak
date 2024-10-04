use aiken/builtin
use aiken/crypto.{ScriptHash, Signature, VerificationKeyHash, blake2b_256}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{Lovelace, from_asset, without_lovelace}
use cardano/transaction.{InlineDatum, Input, Output}
use config
use types.{AccountState, Control, Vk}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, filter_user_inputs,
  inputs_inline_datum, must_find_item, quantity_of,
}

fn pop_to_index(list: List<a>, index: Int) -> List<a> {
  if index == 0 {
    list
  } else {
    pop_to_index(builtin.tail_list(list), index - 1)
  }
}

pub type Transaction {
  inputs: List<Input>,
  reference_inputs: List<Input>,
  outputs: List<Output>,
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

validator cold_control {
  withdraw(
    signatures: (
      Int,
      ScriptHash,
      List<Signature>,
      List<Signature>,
      List<Signature>,
    ),
    _account: Credential,
    tx: Transaction,
  ) {
    let Transaction { inputs, outputs, withdrawals, extra_signatories, .. } = tx

    let (control_index, user_stake, cold_sigs, new_hot_sigs, new_cold_sigs) =
      signatures

    let expected_address =
      Address(Script(config.bullet_hash), Some(Inline(Script(user_stake))))

    let inputs_spent = filter_user_inputs(inputs, expected_address)

    expect Control { cold_cred, cold_cred_hash, .. } =
      inputs
        |> pop_to_index(control_index)
        |> must_find_item(
            fn(input) {
              input.output.value
                |> quantity_of(config.bullet_hash, user_stake)
                |> builtin.equals_integer(1)
            },
          )
        |> inputs_inline_datum()

    expect cold_cred: List<Vk> = cold_cred
    expect cold_cred_hash: List<Credential> = cold_cred_hash

    let message =
      (inputs_spent, outputs)
        |> builtin.serialise_data()
        |> blake2b_256()

    expect [Output { address, value, datum: InlineDatum(datum), .. }, ..] =
      outputs

    let expected_value = from_asset(config.bullet_hash, user_stake, 1)

    expect AccountState {
      quorum: out_quorum,
      hot_cred: out_hot_cred,
      hot_cred_hash: out_hot_cred_hash,
      cold_cred: out_cold_cred,
      cold_cred_hash: out_cold_cred_hash,
    } = datum

    and {
      check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals),
      check_all_valid_vk_sigs(cold_cred, cold_sigs, message),
      without_lovelace(value) == expected_value,
      address == expected_address,
      out_quorum > 0,
      check_all_valid_vk_sigs(out_hot_cred, new_hot_sigs, message),
      check_all_valid_vk_sigs(out_cold_cred, new_cold_sigs, message),
      check_all_tx_observed(out_hot_cred_hash, extra_signatories, withdrawals),
      check_all_tx_observed(out_cold_cred_hash, extra_signatories, withdrawals),
    }
  }

  else(_) {
    False
  }
}
