use aiken/crypto.{Blake2b_256, Hash, Signature, VerificationKey}
use cardano/address.{Credential}

pub type MessageHash =
  Hash<Blake2b_256, ByteArray>

pub type StakeActions {
  Signed(List<Signature>)
  Setup
}

pub type AccountState {
  Control {
    quorum: Int,
    hot_cred: List<Vk>,
    hot_cred_hash: List<Credential>,
    cold_cred: Data,
    cold_cred_hash: Data,
  }
  Nonce
  Vault
}

pub type Vk {
  Secp(VerificationKey)
  Schnorr(VerificationKey)
}
