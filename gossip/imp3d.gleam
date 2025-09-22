import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/order
import gleam/set
import gleam_community/maths
import pushsum
import threed

pub fn setup_imperfect_3d_topology(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) -> Nil {
  let length = case maths.nth_root(int.to_float(dict.size(nodes)), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  threed.recurse_3d(0, 0, 0, length, nodes)

  let unpartnered = set.from_list(dict.keys(nodes))
  recurse_assign_neighbor(nodes, unpartnered, 0)
  Nil
}

pub fn recurse_assign_neighbor(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
  unpartnered: set.Set(Int),
  pos: Int,
) -> Nil {
  case int.compare(set.size(unpartnered), 2) {
    order.Lt -> Nil
    _ -> {
      try_assign_neighbor(nodes, unpartnered, 0, pos)
    }
  }
}

// TODO: complete this function. Might need to pass in a data structure with existing node connections
pub fn try_assign_neighbor(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
  unpartnered: set.Set(Int),
  attempt: Int,
  pos: Int,
) -> Nil {
  case int.compare(attempt, 100) {
    order.Gt -> nodes
    _ -> {
      let second = set.random_element(unpartnered)
      let new_unpartnered = set.remove(set.remove(unpartnered, first), second)
      recurse_assign_neighbor(nodes, new_unpartnered)
    }
  }
}
