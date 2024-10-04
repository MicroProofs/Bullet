use aiken/builtin
use aiken/collection/list.{any}
use cardano/address.{Credential, Script}
use cardano/assets.{Lovelace, PolicyId}
use cardano/transaction.{Output, OutputReference, Transaction}
use config
use types.{ColdCred, HotCred, Intention, ProxyAction, VaultSpend}
use utils.{dataify, inputs_inline_datum, must_find_item, quantity_of}

fn must_have_key_data(
  withdrawals: Pairs<Credential, Lovelace>,
  cred: Data,
) -> Bool {
  expect [Pair(key, _), ..rest] = withdrawals

  dataify(key) == cred || must_have_key_data(rest, cred)
}

/// The bread and butter of Bullet
/// The ultimate contract. A simple tiny withdraw validator that orchestrates all the music
validator proxy_spend {
  withdraw(
    proxy_action: Data<ProxyAction>,
    account: Credential,
    tx: Transaction,
  ) {
    expect Script(own_hash) = account

    let Transaction { reference_inputs, withdrawals, .. } = tx

    // Get control credentials
    expect [
      hot_cred_contract, intention_contract, vault_spend_contract,
      cold_cred_contract, cold_control_contract,
      ..
    ] =
      reference_inputs
        |> must_find_item(
            fn(input) {
              input.output.value
                |> quantity_of(own_hash, "")
                |> builtin.equals_integer(1)
            },
          )
        |> inputs_inline_datum()
        |> builtin.un_constr_data()
        |> builtin.snd_pair()

    if proxy_action == dataify(HotCred) {
      must_have_key_data(withdrawals, hot_cred_contract)
    } else if proxy_action == dataify(Intention) {
      must_have_key_data(withdrawals, intention_contract)
    } else if proxy_action == dataify(VaultSpend) {
      must_have_key_data(withdrawals, vault_spend_contract)
    } else if proxy_action == dataify(ColdCred) {
      must_have_key_data(withdrawals, cold_cred_contract)
    } else {
      must_have_key_data(withdrawals, cold_control_contract)
    }
  }

  mint(_mint_action: Data, _own_policy: PolicyId, tx: Transaction) {
    let Transaction { inputs, .. } = tx

    let one_shot_ref =
      config.one_shot_tx_hash
        |> OutputReference(config.one_shot_output_index)

    any(inputs, fn(input) { input.output_reference == one_shot_ref })
  }

  else(_) {
    False
  }
}
