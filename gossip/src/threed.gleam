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

pub fn setup_3d_topology(
  nodes: List(process.Subject(Result(element, Nil))),
) -> List(process.Subject(Result(element, Nil))) {
  nodes
}
