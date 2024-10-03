use aiken/builtin
use cardano/address.{Credential, Script}
use cardano/assets.{quantity_of}
use cardano/transaction.{Transaction}
use config
use types.{Control, Signed, StakeActions}
use utils.{
  check_tx_observed, check_valid_vk_sigs, inputs_inline_datum, must_find_item,
}

pub fn check_control_creds(
  account: Credential,
  stake_action: Data<StakeActions>,
  tx: Transaction,
) -> Bool {
  expect Signed(signatures) = stake_action

  let Transaction { reference_inputs, extra_signatories, withdrawals, id, .. } =
    tx

  expect Script(own_hash) = account

  // Get control credentials
  expect Control { hot_cred, quorum, hot_cred_hash, .. } =
    reference_inputs
      |> must_find_item(
          fn(input) {
            input.output.value
              |> quantity_of(config.bullet_hash, own_hash)
              |> builtin.equals_integer(1)
          },
        )
      |> inputs_inline_datum()

  let valid_hot_cred = check_valid_vk_sigs(hot_cred, signatures, id)

  let valid_observers =
    check_tx_observed(hot_cred_hash, extra_signatories, withdrawals)

  // Check controller approved tx
  valid_hot_cred + valid_observers >= quorum
}
