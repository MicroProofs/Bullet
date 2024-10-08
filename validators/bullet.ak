use aiken/builtin
use aiken/collection/dict.{to_pairs}
use aiken/collection/list.{any, has}
use aiken/collection/pairs.{has_key}
use aiken/crypto.{Signature, blake2b_256}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{PolicyId, from_asset, to_dict, without_lovelace}
use cardano/certificate.{Certificate}
use cardano/governance.{Voter}
use cardano/transaction.{
  InlineDatum, Output, OutputReference, Redeemer, Transaction, Withdraw,
}
use config
use types.{AccountState, Setup, StakeActions}
use utils.{
  check_all_tx_observed, check_all_valid_vk_sigs, dataify, must_find_key,
}

// UserAccount =
// Address(Script("BULLET"), Some(Inline(Script("USER_SPECIFIC"))))

// UserAccount =
// Address(Script("BULLET"), Some(Inline(Script("TRUE_STAKE_KEY"))))

fn check_for_stake_proxy(tx: Transaction, credential: Data) {
  let proxy_cred = Withdraw(Script(config.stake_proxy_hash))

  let redeemer = must_find_key(tx.redeemers, proxy_cred)

  expect [cred, ..] = builtin.un_list_data(redeemer)

  cred == credential
}

/// Used as an example of how an always true 
/// stake key does not comprimise other user accounts
validator true_stake_bullet {
  else(_) {
    True
  }
}

/// Rely on proxy stake validator for all other validation besides setup
/// Handles user stake key actions including delegation, reward, and voting
validator stake_bullet {
  withdraw(
    stake_action: Data<StakeActions>,
    account: Credential,
    tx: Transaction,
  ) {
    if stake_action == dataify(Setup) {
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

      let expected_value = from_asset(config.bullet_hash, own_hash, 1)

      expect (hot_sigs, cold_sigs): (List<Signature>, List<Signature>) =
        sig_datum

      expect AccountState {
        quorum,
        hot_cred,
        hot_cred_hash,
        cold_cred,
        cold_cred_hash,
      } = datum

      and {
        any(inputs, fn(input) { input.output_reference == one_shot_ref }),
        // Check for account state is setup correctly
        without_lovelace(value) == expected_value,
        address == expected_address,
        quorum > 0,
        check_all_valid_vk_sigs(hot_cred, hot_sigs, one_shot_message),
        check_all_valid_vk_sigs(cold_cred, cold_sigs, one_shot_message),
        check_all_tx_observed(hot_cred_hash, extra_signatories, withdrawals),
        check_all_tx_observed(cold_cred_hash, extra_signatories, withdrawals),
      }
    } else {
      check_for_stake_proxy(tx, account)
    }
  }

  publish(_stake_action: Data, cert: Certificate, tx: Transaction) {
    expect Pair(index, [cred, ..]) = builtin.un_constr_data(cert)

    // Seven is my lucky number 
    // Actually the first seven certificates have the certificate credential as the first field
    //    RegisterCredential {
    //   credential: Credential,
    //   deposit: Never,
    // }
    // UnregisterCredential {
    //   credential: Credential,
    //   refund: Never,
    // }
    // DelegateCredential { credential: Credential, delegate: Delegate }
    // RegisterAndDelegateCredential {
    //   credential: Credential,
    //   delegate: Delegate,
    //   deposit: Lovelace,
    // }
    // RegisterDelegateRepresentative {
    //   delegate_representative: Credential,
    //   deposit: Lovelace,
    // }
    // UpdateDelegateRepresentative { delegate_representative: Credential }
    // UnregisterDelegateRepresentative {
    //   delegate_representative: Credential,
    //   refund: Lovelace,
    // }
    check_for_stake_proxy(tx, cred) && index < 7
  }

  vote(_stake_action: Data, voter: Voter, tx: Transaction) {
    expect Pair(_, [cred, ..]) = builtin.un_constr_data(voter)

    check_for_stake_proxy(tx, cred)
  }

  else(_) {
    False
  }
}

fn check_for_proxy(tx: Transaction) -> Bool {
  let proxy_cred = Script(config.proxy_hash)

  has_key(tx.withdrawals, proxy_cred)
}

/// Entry point for a user spending their utxos
validator bullet {
  spend(_d, _r, _o, tx: Transaction) {
    check_for_proxy(tx)
  }

  /// Support single time minting per user
  mint(_r, own_policy: PolicyId, tx: Transaction) {
    let Transaction { mint, redeemers, .. } = tx

    expect [Pair(name, quantity)] =
      mint
        |> to_dict
        |> to_pairs
        |> must_find_key(own_policy)
        |> to_pairs

    or {
      quantity == -1,
      {
        let script_purp = Withdraw(Script(name))
        let expected_action: Redeemer = Setup

        and {
          quantity == 1,
          has(redeemers, Pair(script_purp, expected_action)),
        }
      },
    }
  }

  else(_) {
    False
  }
}
