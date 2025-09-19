import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam_community/maths

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

pub fn setup_3d_topology(
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
) -> List(process.Subject(Result(element, Nil))) {
  let length = case maths.nth_root(int.to_float(n), 3) {
    Error(_) -> 0
    Ok(result) -> float.truncate(result)
  }
  recurse_3d(0, 0, 0, length, nodes)
}

pub fn recurse_3d(
  x: Int,
  y: Int,
  z: Int,
  dim_length: Int,
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
) {
  // exit condition
  case int.compare(x, dim_length) {
    order.Lt -> {
      let curr_idx = index_3d_to_1d(x, y, z, dim_length)

      // add neighbors
      case int.compare(x + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x + 1, y, z, dim_length)
          assign_neighbor(curr_idx, neighbor_idx, nodes)
        }
      }
      case int.compare(y + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x, y + 1, z, dim_length)
          assign_neighbor(curr_idx, neighbor_idx, nodes)
        }
      }
      case int.compare(z + 1, dim_length) {
        order.Lt -> {
          let neighbor_idx = index_3d_to_1d(x, y, z + 1, dim_length)
          assign_neighbor(curr_idx, neighbor_idx, nodes)
        }
      }

      // move to next node
      case int.compare(z + 1, dim_length) {
        order.Lt -> recurse_3d(x, y, z + 1, dim_length, nodes)
      }
      case int.compare(y + 1, dim_length) {
        order.Lt -> recurse_3d(x, y + 1, 0, dim_length, nodes)
      }
      case int.compare(x + 1, dim_length) {
        order.Lt -> recurse_3d(x + 1, 0, 0, dim_length, nodes)
      }
    }
    _ -> []
  }
}

pub fn assign_neighbor(
  index1: Int,
  index2: Int,
  nodes: Dict(Int, process.Subject(Result(element, Nil))),
) {
  case dict.get(nodes, index1) {
    Ok(node1) -> {
      case dict.get(nodes, index2) {
        Ok(node2) -> {
          process.send(node1, AddNeighbor(node2))
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
