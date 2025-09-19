import threed

pub fn setup_imperfect_3d_topology(
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
) -> List(process.Subject(Result(element, Nil))) {
  let length = case maths.nth_root(int.to_float(n), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  recurse_3d(0, 0, 0, length, nodes)
  assign_final_neighbor(nodes)
}

pub fn assign_final_neighbors(
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
) {
  let unpartnered = set.from_list(Dict.keys(nodes))
  recurse_assign_neighbor(nodes, unpartnered, 0)
}

pub fn recurse_assign_neighbor(
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
  unpartnered: Set(Int),
  pos: Int,
) {
  case set.size(unpartnered) {
    0 -> nodes
    1 -> nodes
    _ -> {
      try_assign_neighbor(nodes, unpartnered, 0, pos)
    }
  }
}

// TODO: complete this function
pub fn try_assign_neighbor(
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
  unpartnered: Set(Int),
  attempt: Int,
  pos: Int,
) {
  case int.compare(attempt, 100) {
    order.Gt -> nodes
    _ -> {
      let second = set.random_element(unpartnered)
      let new_unpartnered = set.remove(set.remove(unpartnered, first), second)
      recurse_assign_neighbor(nodes, new_unpartnered)
    }
  }
}
