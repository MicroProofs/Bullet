use cardano/address.{Credential}
use cardano/transaction.{Transaction}
use cardano/assets.{PolicyId}

/// The bread and butter of Bullet
/// The ultimate contract. A simple tiny withdraw validator that orchestrates all the music
validator proxy {
  withdraw(proxy_action: Data, account: Credential, tx: Transaction) {
    fail
  }

  mint(_mint_action: Data, own_policy: PolicyId, tx: Transaction) {
    fail
  }

  else(_) {
    False
  }
}
