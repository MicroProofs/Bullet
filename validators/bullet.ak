use aiken/collection/dict.{to_pairs}
use aiken/collection/list.{any}
use aiken/collection/pairs.{has_key}
use cardano/address.{Script}
use cardano/assets.{PolicyId, to_dict}
use cardano/transaction.{OutputReference, Redeemer, Transaction, Withdraw}
use config
use utils.{must_find}
use types.{Setup, StakeActions}



validator stake_bullet {
  withdraw(stake_action: StakeActions, _a, tx: Transaction) {
    when stake_action is {
      Setup -> {
        let inputs = tx.inputs

        let one_shot_ref =
          config.one_shot_tx_hash
            |> OutputReference(config.one_shot_output_index)

        any(inputs, fn(input) { input.output_reference == one_shot_ref })
      }

      _ -> fail
    }
  }

  else(_) {
    fail
  }
}

validator bullet {
  spend(_d, _r, _o, tx: Transaction) {
    let proxy_cred = Script(config.proxy_hash)

    let withdrawals = tx.withdrawals

    has_key(withdrawals, proxy_cred)
  }

  /// Support single time minting per address
  mint(_r, own_policy: PolicyId, tx: Transaction) {
    expect [Pair(name, 1)] =
      tx.mint
        |> to_dict
        |> to_pairs
        |> must_find(own_policy)
        |> to_pairs

    let script_purp = Withdraw(Script(name))
    let expected_action: Redeemer = Setup

    let redeemer = tx.redeemers |> must_find(script_purp)

    redeemer == expected_action
  }

  else(_) {
    fail
  }
}
