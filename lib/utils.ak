use aiken/crypto.{
  Signature, VerificationKeyHash, verify_ecdsa_signature,
  verify_schnorr_signature,
}
use aiken/primitive/bytearray.{is_empty}
use cardano/address.{Credential, Script, VerificationKey}
use cardano/assets.{Lovelace}
use cardano/transaction.{InlineDatum, Input}
use types.{MessageHash, Schnorr, Secp, Vk}

pub fn must_find_key(pairs: Pairs<a, b>, key: a) -> b {
  expect [Pair(k2, value), ..rest] = pairs

  if k2 == key {
    value
  } else {
    must_find_key(rest, key)
  }
}

pub fn must_find_item(list: List<a>, predicate: fn(a) -> Bool) -> a {
  expect [item, ..rest] = list

  if predicate(item) {
    item
  } else {
    must_find_item(rest, predicate)
  }
}

pub fn inputs_inline_datum(i: Input) -> Data {
  expect InlineDatum(d) = i.output.datum

  d
}

/// Returns count of non-empty signatures that are valid
/// Fails if any non-empty signature is invalid
pub fn check_valid_vk_sigs(
  vks: List<Vk>,
  signatures: List<Signature>,
  message: MessageHash,
) -> Int {
  when vks is {
    [] -> 0
    [vk, ..rest] -> {
      expect [sig, ..others] = signatures

      if is_empty(sig) {
        check_valid_vk_sigs(rest, others, message)
      } else {
        when vk is {
          // ranked by probable usage
          Schnorr(vk) ->
            if vk |> verify_schnorr_signature(message, sig) {
              1 + check_valid_vk_sigs(rest, others, message)
            } else {
              fail
            }
          Secp(vk) ->
            if vk |> verify_ecdsa_signature(message, sig) {
              1 + check_valid_vk_sigs(rest, others, message)
            } else {
              fail
            }
        }
      }
    }
  }
}

pub fn check_tx_observed(
  vkhs: List<Credential>,
  signatories: List<VerificationKeyHash>,
  withdrawals: Pairs<Credential, Lovelace>,
) -> Int {
  when vkhs is {
    [] -> 0
    [vkh, ..rest] ->
      when vkh is {
        VerificationKey(vkh) ->
          1 + (
            signatories
              |> must_take_until(vkh)
              |> check_tx_observed(rest, _, withdrawals)
          )
        Script(_) as sc ->
          1 + (
            withdrawals
              |> must_take_key_until(sc)
              |> check_tx_observed(rest, signatories, _)
          )
      }
  }
}

pub fn must_take_until(list: List<a>, item: a) -> List<a> {
  expect [first, ..rest] = list

  if item == first {
    rest
  } else {
    must_take_until(rest, item)
  }
}

pub fn must_take_key_until(list: List<Pair<a, b>>, key: a) -> List<Pair<a, b>> {
  expect [Pair(key2, _), ..rest] = list

  if key == key2 {
    rest
  } else {
    must_take_key_until(rest, key)
  }
}
