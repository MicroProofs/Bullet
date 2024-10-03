use bullet
use cardano/address.{Address, Inline, Script, VerificationKey}
use cardano/assets.{add, from_asset, zero}
use cardano/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, Redeemer,
  Transaction, Withdraw,
}
use config
use types.{AccountState, Setup}

test can_setup_stake() {
  let account = Script("blargh_uuuug")

  let address = Address(Script("blue"), None)

  let expected_address =
    Address(Script(config.bullet_hash), Some(Inline(account)))

  let expected_value = from_asset(config.bullet_hash, "blargh_uuuug", 1)

  let account_state = AccountState(1, [], [], [], [])

  let input =
    Input(
      config.new_user_tx_hash
        |> OutputReference(config.new_user_output_index),
      Output(address, zero, NoDatum, None),
    )

  let outputs =
    [
      Output(expected_address, expected_value, InlineDatum(account_state), None),
      Output(address, zero, InlineDatum([[], []]), None),
    ]

  let tx =
    Transaction { ..transaction.placeholder, inputs: [input], outputs: outputs }

  bullet.stake_bullet.withdraw(Setup, account, tx)
}

test can_mint_bullet() {
  let name = "bleh_blah_bleh"

  let own_policy = "foo_blegghhh"

  let r: Redeemer = Setup
  let other: Redeemer = 0 |> Some
  let other2: Redeemer = 0

  let tx =
    Transaction {
      ..transaction.placeholder,
      mint: from_asset(own_policy, name, 1),
      redeemers: [
        Pair(Mint(#"aabbbcccddeeff"), other),
        Pair(Withdraw(Script(#"aabbbccc")), other2),
        Pair(Withdraw(Script(name)), r),
      ],
    }

  bullet.bullet.mint("555555", own_policy, tx)
}

test cant_mint_extra_bullet() fail {
  let name = "bleh_blah_bleh"

  let own_policy = "foo_blegghhh"

  let r: Redeemer = Setup
  let other: Redeemer = 0 |> Some
  let other2: Redeemer = 0

  let tx =
    Transaction {
      ..transaction.placeholder,
      mint: from_asset(own_policy, name, 1) |> add(own_policy, own_policy, 1),
      redeemers: [
        Pair(Mint(#"aabbbcccddeeff"), other),
        Pair(Withdraw(Script(#"aabbbccc")), other2),
        Pair(Withdraw(Script(name)), r),
      ],
    }

  bullet.bullet.mint("555555", own_policy, tx)
}

test can_spend_bullet() {
  let tx =
    Transaction {
      ..transaction.placeholder,
      withdrawals: [
        Pair(Script(#"aabbbccc"), 0),
        Pair(Script(config.proxy_hash), 1000000),
        Pair(VerificationKey(#"aabbbcccddeeff"), 0),
      ],
    }

  bullet.bullet.spend(None, 0, "ouch", tx)
}

test cant_steal_bullet() fail {
  let tx =
    Transaction {
      ..transaction.placeholder,
      withdrawals: [
        Pair(Script(#"aabbbccc"), 0),
        Pair(VerificationKey(#"aabbbcccddeeff"), 0),
      ],
    }

  bullet.bullet.spend(None, 0, "ouch", tx)
}
