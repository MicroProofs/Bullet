use aiken/builtin
use aiken/collection/list.{all}
use aiken/crypto.{ScriptHash, Signature}
use cardano/address.{Credential}
use cardano/assets.{quantity_of}
use cardano/transaction.{Transaction}
use config
use types.{Control, Vk}
use utils.{inputs_inline_datum, must_find_item}

validator hot_cred {
  withdraw(
    signatures: (ScriptHash, List<Signature>),
    _account: Credential,
    tx: Transaction,
  ) {
    let Transaction { inputs, reference_inputs, .. } = tx

    let (user_stake, _sigs) = signatures

    expect Control { quorum, hot_cred, hot_cred_hash, .. } =
      reference_inputs
        |> must_find_item(
            fn(input) {
              input.output.value
                |> quantity_of(config.bullet_hash, user_stake)
                |> builtin.equals_integer(1)
            },
          )
        |> inputs_inline_datum()

    expect _quorum: Int = quorum
    expect _hot_cred: List<Vk> = hot_cred
    expect _hot_cred_hash: List<Credential> = hot_cred_hash

    all(inputs, fn(_input) { fail })
  }

  else(_) {
    False
  }
}
