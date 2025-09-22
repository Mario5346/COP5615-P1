import gleam/list

pub fn random_element(l: List(Int)) -> Int {
  case l {
    [] -> 0
    _ -> {
      case list.first(list.sample(l, 1)) {
        Ok(x) -> x
        _ -> 0
      }
    }
  }
}
