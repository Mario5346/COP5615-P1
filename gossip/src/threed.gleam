import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/order
import gleam_community/maths
import gossalg
import pushsum

@external(erlang, "math", "ceil")
pub fn ceiling(x: Float) -> Float

pub fn number_of_3d_nodes(n: Int) -> Int {
  case maths.nth_root(int.to_float(n), 3) {
    Error(_) -> {
      0
    }
    Ok(result) -> {
      let dim_length = float.truncate(ceiling(result))
      io.println("Dimension: " <> int.to_string(dim_length))
      dim_length * dim_length * dim_length
    }
  }
}

pub fn index_3d_to_1d(x: Int, y: Int, z: Int, dim_length: Int) -> Int {
  x * dim_length * dim_length + y * dim_length + z
}

pub fn setup_3d_topology_pushsum(
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) -> Nil {
  let length = case maths.nth_root(int.to_float(dict.size(nodes)), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  recurse_3d_pushsum(0, 0, 0, length, nodes)
}

pub fn recurse_3d_pushsum(
  x: Int,
  y: Int,
  z: Int,
  dim_length: Int,
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) {
  // exit condition
  case int.compare(x, dim_length) {
    order.Lt -> {
      let curr_idx = index_3d_to_1d(x, y, z, dim_length)

      // add neighbors
      case int.compare(x + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x + 1, y, z, dim_length)
          assign_neighbor_pushsum(curr_idx, neighbor_idx, nodes)
        }
        _ -> Nil
      }
      case int.compare(y + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x, y + 1, z, dim_length)
          assign_neighbor_pushsum(curr_idx, neighbor_idx, nodes)
        }
        _ -> Nil
      }
      case int.compare(z + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x, y, z + 1, dim_length)
          assign_neighbor_pushsum(curr_idx, neighbor_idx, nodes)
        }
        _ -> Nil
      }

      // move to next node
      case int.compare(z + 1, dim_length) {
        order.Lt -> recurse_3d_pushsum(x, y, z + 1, dim_length, nodes)
        _ -> Nil
      }
      case int.compare(y + 1, dim_length) {
        order.Lt -> recurse_3d_pushsum(x, y + 1, 0, dim_length, nodes)
        _ -> Nil
      }
      case int.compare(x + 1, dim_length) {
        order.Lt -> recurse_3d_pushsum(x + 1, 0, 0, dim_length, nodes)
        _ -> Nil
      }
    }
    _ -> Nil
  }
}

pub fn assign_neighbor_pushsum(
  index1: Int,
  index2: Int,
  nodes: dict.Dict(Int, process.Subject(pushsum.PushSumMessage(e))),
) {
  case dict.get(nodes, index1) {
    Ok(node1) -> {
      case dict.get(nodes, index2) {
        Ok(node2) -> {
          // io.println(
          //   "Assigning neighbor: "
          //   <> int.to_string(index1)
          //   <> " <-> "
          //   <> int.to_string(index2),
          // )
          process.send(node1, pushsum.AddNeighbor(index2, node2))
          process.send(node2, pushsum.AddNeighbor(index1, node1))
        }
        Error(_) -> {
          io.println("Error getting node2 at index " <> int.to_string(index2))
        }
      }
    }
    Error(_) -> {
      io.println("Error getting node1 at index " <> int.to_string(index1))
    }
  }
}

// ------------------------------------------------------------

pub fn setup_3d_topology_gossip(
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
) -> Nil {
  let length = case maths.nth_root(int.to_float(dict.size(nodes)), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  recurse_3d_gossip(0, 0, 0, length, nodes)
}

pub fn recurse_3d_gossip(
  x: Int,
  y: Int,
  z: Int,
  dim_length: Int,
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
) {
  // exit condition
  case int.compare(x, dim_length) {
    order.Lt -> {
      let curr_idx = index_3d_to_1d(x, y, z, dim_length)

      // add neighbors
      case int.compare(x + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x + 1, y, z, dim_length)
          assign_neighbor_gossip(curr_idx, neighbor_idx, nodes)
        }
        _ -> Nil
      }
      case int.compare(y + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x, y + 1, z, dim_length)
          assign_neighbor_gossip(curr_idx, neighbor_idx, nodes)
        }
        _ -> Nil
      }
      case int.compare(z + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x, y, z + 1, dim_length)
          assign_neighbor_gossip(curr_idx, neighbor_idx, nodes)
        }
        _ -> Nil
      }

      // move to next node
      case int.compare(z + 1, dim_length) {
        order.Lt -> recurse_3d_gossip(x, y, z + 1, dim_length, nodes)
        _ -> Nil
      }
      case int.compare(y + 1, dim_length) {
        order.Lt -> recurse_3d_gossip(x, y + 1, 0, dim_length, nodes)
        _ -> Nil
      }
      case int.compare(x + 1, dim_length) {
        order.Lt -> recurse_3d_gossip(x + 1, 0, 0, dim_length, nodes)
        _ -> Nil
      }
    }
    _ -> Nil
  }
}

pub fn assign_neighbor_gossip(
  index1: Int,
  index2: Int,
  nodes: dict.Dict(Int, process.Subject(gossalg.Message(e))),
) {
  case dict.get(nodes, index1) {
    Ok(node1) -> {
      case dict.get(nodes, index2) {
        Ok(node2) -> {
          // io.println(
          //   "Assigning neighbor: "
          //   <> int.to_string(index1)
          //   <> " <-> "
          //   <> int.to_string(index2),
          // )
          process.send(node1, gossalg.AddNeighbor(node2))
          process.send(node2, gossalg.AddNeighbor(node1))
        }
        Error(_) -> {
          io.println("Error getting node2 at index " <> int.to_string(index2))
        }
      }
    }
    Error(_) -> {
      io.println("Error getting node1 at index " <> int.to_string(index1))
    }
  }
}
