use aiken/builtin
use aiken/collection/list.{any}
use aiken/collection/pairs.{has_key}
use aiken/crypto.{ScriptHash}
use cardano/address.{Credential, Script}
use cardano/assets.{PolicyId, quantity_of}
use cardano/transaction.{Output, OutputReference, Transaction}
use config
use types.{ColdCred, HotCred, Intention, ProxyAction, ProxyState, VaultSpend}
use utils.{dataify, inputs_inline_datum, must_find_item}

fn check_for_proxy(tx: Transaction, script_hash: ScriptHash) -> Bool {
  let proxy_cred = Script(script_hash)

  let withdrawals = tx.withdrawals

  has_key(withdrawals, proxy_cred)
}

/// The bread and butter of Bullet
/// The ultimate contract. A simple tiny withdraw validator that orchestrates all the music
validator proxy {
  withdraw(
    proxy_action: Data<ProxyAction>,
    account: Credential,
    tx: Transaction,
  ) {
    expect Script(own_hash) = account

    // Get control credentials
    expect ProxyState {
      hot_cred_contract,
      intention_contract,
      vault_spend_contract,
      cold_cred_contract,
      cold_control_contract,
    } =
      tx.reference_inputs
        |> must_find_item(
            fn(input) {
              input.output.value
                |> quantity_of(own_hash, "")
                |> builtin.equals_integer(1)
            },
          )
        |> inputs_inline_datum()

    if proxy_action == dataify(HotCred) {
      check_for_proxy(tx, hot_cred_contract)
    } else if proxy_action == dataify(Intention) {
      check_for_proxy(tx, intention_contract)
    } else if proxy_action == dataify(VaultSpend) {
      check_for_proxy(tx, vault_spend_contract)
    } else if proxy_action == dataify(ColdCred) {
      check_for_proxy(tx, cold_cred_contract)
    } else {
      check_for_proxy(tx, cold_control_contract)
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
