pub fn must_find(pairs: Pairs<a, b>, key: a) -> b {
  expect [Pair(k2, value), ..rest] = pairs

  if k2 == key {
    value
  } else {
    must_find(rest, key)
  }
}
