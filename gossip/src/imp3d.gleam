import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/set
import gleam_community/maths
import gossalg
import pushsum
import threed

pub fn setup_imperfect_3d_topology_pushsum(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) -> Nil {
  let length = case maths.nth_root(int.to_float(dict.size(nodes)), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  threed.recurse_3d_pushsum(0, 0, 0, length, nodes)

  let unpartnered = set.from_list(dict.keys(nodes))
  recurse_assign_neighbor_pushsum(nodes, unpartnered, 0)
  Nil
}

pub fn recurse_assign_neighbor_pushsum(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
  unpartnered: set.Set(Int),
  pos: Int,
) -> Nil {
  case int.compare(set.size(unpartnered), 2) {
    order.Lt -> Nil
    _ -> {
      let unp = set.to_list(unpartnered)
      let node1 = random_element(unp)
      let node2 = random_element(unp)
      case int.compare(node1, node2) {
        order.Eq -> recurse_assign_neighbor_pushsum(nodes, unpartnered, pos)
        _ -> {
          case try_assign_neighbor_pushsum(nodes, node1, node2) {
            True -> {
              let new_unpartnered =
                set.delete(set.delete(unpartnered, node1), node2)
              recurse_assign_neighbor_pushsum(nodes, new_unpartnered, pos + 1)
            }
            False ->
              recurse_assign_neighbor_pushsum(nodes, unpartnered, pos + 1)
          }
        }
      }
    }
  }
}

pub fn try_assign_neighbor_pushsum(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
  node1: Int,
  node2: Int,
) -> Bool {
  case dict.get(nodes, node1) {
    Ok(n1) -> {
      case dict.get(nodes, node2) {
        Ok(n2) -> {
          let neighbors = process.call(n1, 100, pushsum.GetNeighbors)
          case dict.get(neighbors, node2) {
            Ok(_) -> False
            _ -> {
              process.send(n1, pushsum.AddNeighbor(node2, n2))
              process.send(n2, pushsum.AddNeighbor(node1, n1))
              True
            }
          }
        }
        Error(_) -> False
      }
    }
    Error(_) -> False
  }
}

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

// -------------------------------------------------------------

pub fn setup_imperfect_3d_topology_gossip(
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
) -> Nil {
  let length = case maths.nth_root(int.to_float(dict.size(nodes)), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  threed.recurse_3d_gossip(0, 0, 0, length, nodes)

  let unpartnered = set.from_list(dict.keys(nodes))
  recurse_assign_neighbor_gossip(nodes, unpartnered, 0)
  Nil
}

pub fn recurse_assign_neighbor_gossip(
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
  unpartnered: set.Set(Int),
  pos: Int,
) -> Nil {
  case int.compare(set.size(unpartnered), 2) {
    order.Lt -> Nil
    _ -> {
      let unp = set.to_list(unpartnered)
      let node1 = random_element(unp)
      let node2 = random_element(unp)

      case int.compare(node1, node2) {
        order.Eq -> recurse_assign_neighbor_gossip(nodes, unpartnered, pos)
        _ -> {
          case try_assign_neighbor_gossip(nodes, node1, node2) {
            True -> {
              let new_unpartnered =
                set.delete(set.delete(unpartnered, node1), node2)
              recurse_assign_neighbor_gossip(nodes, new_unpartnered, pos + 1)
            }
            False -> recurse_assign_neighbor_gossip(nodes, unpartnered, pos + 1)
          }
        }
      }
    }
  }
}

pub fn try_assign_neighbor_gossip(
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
  node1: Int,
  node2: Int,
) -> Bool {
  case dict.get(nodes, node1) {
    Ok(n1) -> {
      case dict.get(nodes, node2) {
        Ok(n2) -> {
          process.send(n1, gossalg.AddNeighbor(n2))
          process.send(n2, gossalg.AddNeighbor(n1))
          True
        }
        Error(_) -> False
      }
    }
    Error(_) -> False
  }
}
