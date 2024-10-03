use aiken/crypto.{ScriptHash, Signature}
use cardano/address.{Credential}
use cardano/transaction.{Transaction}
use config

validator hot_cred {
  withdraw(
    _signatures: (ScriptHash, List<Signature>),
    _account: Credential,
    _tx: Transaction,
  ) {
    let _bullet_hash = config.bullet_hash

    fail
  }

  else(_) {
    False
  }
}
