use aiken/collection/dict.{to_pairs}
use aiken/collection/list.{any}
use aiken/collection/pairs.{has_key}
use bullet/validations.{check_control_creds}
use cardano/address.{Address, Credential, Inline, Script}
use cardano/assets.{PolicyId, quantity_of, to_dict}
use cardano/certificate.{
  Certificate, DelegateCredential, RegisterAndDelegateCredential,
  RegisterCredential, RegisterDelegateRepresentative, UnregisterCredential,
  UnregisterDelegateRepresentative, UpdateDelegateRepresentative,
}
use cardano/governance.{
  ConstitutionalCommitteeMember, DelegateRepresentative, Voter,
}
use cardano/transaction.{
  Output, OutputReference, Redeemer, Transaction, Withdraw,
}
use config
use types.{Setup, StakeActions}
use utils.{must_find_key}

validator stake_bullet {
  withdraw(
    stake_action: Data<StakeActions>,
    account: Credential,
    tx: Transaction,
  ) {
    let setup: Data = Setup

    if stake_action == setup {
      let Transaction { inputs, outputs, .. } = tx

      let one_shot_ref =
        config.one_shot_tx_hash
          |> OutputReference(config.one_shot_output_index)

      expect Script(own_hash) = account

      // TODO: check hot creds and cold creds and hashes are valid
      expect [Output { address, value, datum, .. }, ..] = outputs

      let expected_address =
        Address(Script(config.bullet_hash), Some(Inline(account)))

      and {
        any(inputs, fn(input) { input.output_reference == one_shot_ref }),
        // Check for account state is setup correctly
        quantity_of(value, config.bullet_hash, own_hash) == 1,
        address == expected_address,
      }
    } else {
      check_control_creds(account, stake_action, tx)
    }
  }

  publish(stake_action: Data<StakeActions>, cert: Certificate, tx: Transaction) {
    when cert is {
      RegisterCredential { credential, .. } |
      UnregisterCredential { credential, .. } |
      DelegateCredential { credential, .. } |
      RegisterAndDelegateCredential { credential, .. } |
      RegisterDelegateRepresentative { delegate_representative: credential, .. } |
      UpdateDelegateRepresentative { delegate_representative: credential } |
      UnregisterDelegateRepresentative {
        delegate_representative: credential,
        ..
      } -> {
        let account = credential

        check_control_creds(account, stake_action, tx)
      }

      _ -> False
    }
  }

  /// Update a delegate representative (a.k.a DRep). The certificate also contains
  /// metadata which aren't visible on-chain.
  /// UnRegister a delegate representative, and refund back its past deposit.
  vote(stake_action: Data<StakeActions>, voter: Voter, tx: Transaction) {
    when voter is {
      ConstitutionalCommitteeMember(credential) |
      DelegateRepresentative(credential) -> {
        let account = credential

        check_control_creds(account, stake_action, tx)
      }
      _ -> False
    }
  }

  else(_) {
    False
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
        |> must_find_key(own_policy)
        |> to_pairs

    let script_purp = Withdraw(Script(name))
    let expected_action: Redeemer = Setup

    let redeemer = tx.redeemers |> must_find_key(script_purp)

    redeemer == expected_action
  }

  else(_) {
    False
  }
}
