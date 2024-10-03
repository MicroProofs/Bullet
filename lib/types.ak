use aiken/crypto.{Blake2b_256, Hash, VerificationKey}
use cardano/address.{Credential}

pub type MessageHash =
  Hash<Blake2b_256, ByteArray>

pub type StakeActions {
  Setup
  Signed
}

pub type ProxyAction {
  HotCred
  Intention
  VaultSpend
  ColdCred
  ColdControl
}

pub type AccountState {
  quorum: Int,
  hot_cred: List<Vk>,
  hot_cred_hash: List<Credential>,
  cold_cred: List<Vk>,
  cold_cred_hash: List<Credential>,
}

pub type UtxoStates {
  Control {
    quorum: Data<Int>,
    hot_cred: Data<List<Vk>>,
    hot_cred_hash: Data<List<Credential>>,
    cold_cred: Data<List<Vk>>,
    cold_cred_hash: Data<List<Credential>>,
  }
  Nonce(Int)
  Vault
}

pub type ProxyState {
  hot_cred_contract: Credential,
  intention_contract: Credential,
  vault_spend_contract: Credential,
  cold_cred_contract: Credential,
  cold_control_contract: Credential,
}

pub type Vk {
  Secp(VerificationKey)
  Schnorr(VerificationKey)
}
