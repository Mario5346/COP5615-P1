import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gossalg
import pushsum

pub fn main() {
  case argv.load().arguments {
    ["project2", first, second, third] -> {
      case int.parse(first) {
        Ok(result) -> {
          let nodes = result
          io.println("Number of Nodes: " <> int.to_string(nodes))
          let args = []
          let args = list.append(args, nodes)

          case second {
            "full" -> {
              io.println("topology is full")
            }
            "3D" -> {
              io.println("topology is 3D")
            }
            "line" -> {
              io.println("topology is line")
            }
            "imp3D" -> {
              io.println("topology is full")
            }
            _ -> {
              io.println("INVALID TOPOLOGY")
            }
          }
          let args = list.append(args, second)

          case third {
            "gossip" -> {
              io.println("Algorithm is gossip")
            }
            "push-sum" -> {
              io.println("Algorithm is push-sum")
            }
            _ -> {
              io.println("INVALID ALGORITHM")
            }
          }
          let args = list.append(args, third)
        }
        _ -> io.println("n is not int")
      }
    }
    _ ->
      io.println("usage: gleam run project2 <numNodes> <topology> <algorithm>")
  }
}
