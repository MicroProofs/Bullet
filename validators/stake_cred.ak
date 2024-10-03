use aiken/crypto.{VerificationKeyHash}
use cardano/address.{Credential}
use cardano/assets.{Lovelace}
use cardano/transaction.{Input}

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
  withdraw(_user: Credential, _account: Credential, _tx: Transaction) {
    fail
  }

  else(_) {
    False
  }
}
