use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/collection/list.{any}
use aiken/collection/pairs.{has_key}
use aiken/crypto.{Signature, blake2b_256}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{PolicyId, quantity_of, to_dict}
use cardano/certificate.{Certificate}
use cardano/governance.{Voter}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Redeemer, Transaction, Withdraw,
}
use config
use types.{Control, Setup, StakeActions, Vk}
use utils.{check_all_tx_observed, check_all_valid_vk_sigs, must_find_key}

fn check_for_proxy(tx: Transaction) -> Bool {
  let proxy_cred = Script(config.proxy_hash)

  let withdrawals = tx.withdrawals

  has_key(withdrawals, proxy_cred)
}

/// Rely on proxy validator for all other validation besides setup
validator stake_bullet {
  withdraw(
    stake_action: Data<StakeActions>,
    account: Credential,
    tx: Transaction,
  ) {
    let setup: Data = Setup

    if stake_action == setup {
      let Transaction { inputs, outputs, withdrawals, extra_signatories, .. } =
        tx

      let one_shot_ref =
        config.new_user_tx_hash
          |> OutputReference(config.new_user_output_index)

      // This should come from a pub key anyway 
      // so this is fine to one time validate credentials are
      // valid
      let one_shot_message =
        one_shot_ref
          |> builtin.serialise_data()
          |> concat(config.name_space, _)
          |> blake2b_256()

      expect Script(own_hash) = account

      // The reason I store sigs in the next output is to simplify the redeemer
      // And this is only run once per user so impact is minimal
      expect [
        Output { address, value, datum: InlineDatum(datum), .. },
        Output { datum: InlineDatum(sig_datum), .. },
        ..
      ] = outputs

      let expected_address =
        Address(Script(config.bullet_hash), Some(Inline(account)))

      expect (hot_sigs, cold_sigs): (List<Signature>, List<Signature>) =
        sig_datum

      expect Control {
        quorum,
        hot_cred,
        hot_cred_hash,
        cold_cred,
        cold_cred_hash,
      } = datum

      expect cold_cred: List<Vk> = cold_cred

      expect cold_cred_hash: List<Credential> = cold_cred_hash

      and {
        any(inputs, fn(input) { input.output_reference == one_shot_ref }),
        // Check for account state is setup correctly
        quantity_of(value, config.bullet_hash, own_hash) == 1,
        address == expected_address,
        quorum > 0,
        check_all_valid_vk_sigs(hot_cred, hot_sigs, one_shot_message),
        check_all_valid_vk_sigs(cold_cred, cold_sigs, one_shot_message),
        check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals),
        check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals),
      }
    } else {
      check_for_proxy(tx)
    }
  }

  publish(
    _stake_action: Data<StakeActions>,
    _cert: Certificate,
    tx: Transaction,
  ) {
    check_for_proxy(tx)
  }

  /// Update a delegate representative (a.k.a DRep). The certificate also contains
  /// metadata which aren't visible on-chain.
  /// UnRegister a delegate representative, and refund back its past deposit.
  vote(_stake_action: Data<StakeActions>, _voter: Voter, tx: Transaction) {
    check_for_proxy(tx)
  }

  else(_) {
    False
  }
}

validator bullet {
  spend(_d, _r, _o, tx: Transaction) {
    check_for_proxy(tx)
  }

  /// Support single time minting per address
  mint(_r, own_policy: PolicyId, tx: Transaction) {
    expect [Pair(name, quantity)] =
      tx.mint
        |> to_dict
        |> to_pairs
        |> must_find_key(own_policy)
        |> to_pairs

    or {
      quantity == -1,
      {
        let script_purp = Withdraw(Script(name))
        let expected_action: Redeemer = Setup

        let redeemer = tx.redeemers |> must_find_key(script_purp)

        and {
          quantity == 1,
          redeemer == expected_action,
        }
      },
    }
  }

  else(_) {
    False
  }
}
