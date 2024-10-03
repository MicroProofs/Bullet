use aiken/builtin
use aiken/crypto.{Signature, VerificationKeyHash, blake2b_256}
use cardano/address.{Credential, Script}
use cardano/assets.{Lovelace, quantity_of}
use cardano/transaction.{Input}
use config
use types.{Control, Vk}
use utils.{
  check_tx_observed, check_valid_vk_sigs, dataify, inputs_inline_datum,
  must_find_item,
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

validator stake_proxy {
  withdraw(
    signatures: (Credential, List<Signature>),
    _account: Credential,
    tx: Transaction,
  ) {
    let Transaction {
      reference_inputs,
      withdrawals,
      extra_signatories,
      certificates,
      votes,
      ..
    } = tx

    expect (Script(user_hash), sigs) = signatures

    expect Control { quorum, hot_cred, hot_cred_hash, .. } =
      reference_inputs
        |> must_find_item(
            fn(input) {
              input.output.value
                |> quantity_of(config.bullet_hash, user_hash)
                |> builtin.equals_integer(1)
            },
          )
        |> inputs_inline_datum()

    expect quorum: Int = quorum
    expect hot_cred_hash: List<Credential> = hot_cred_hash

    if hot_cred == dataify([]) {
      check_tx_observed(hot_cred_hash, extra_signatories, withdrawals) >= quorum
    } else {
      expect hot_cred: List<Vk> = hot_cred
      let message =
        (withdrawals, certificates, votes)
          |> builtin.serialise_data()
          |> blake2b_256()

      check_tx_observed(hot_cred_hash, extra_signatories, withdrawals) + check_valid_vk_sigs(
        hot_cred,
        sigs,
        message,
      ) >= quorum
    }
  }

  else(_) {
    False
  }
}
