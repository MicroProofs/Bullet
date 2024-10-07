use cardano/address.{Address, Script}
use cardano/assets.{zero}
use cardano/transaction.{Input, NoDatum, Output, OutputReference, Transaction}
use config
use proxy

test can_setup_stake() {
  let one_shot_ref =
    config.one_shot_tx_hash
      |> OutputReference(config.one_shot_output_index)

  let address = Address(Script("blue"), None)

  let input = Input(one_shot_ref, Output(address, zero, NoDatum, None))

  let tx = Transaction { ..transaction.placeholder, inputs: [input] }

  proxy.proxy_spend.mint(0, "POKAMON", tx)
}
