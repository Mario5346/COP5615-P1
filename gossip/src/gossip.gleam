import argv
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import gossalg
import imp3d
import pushsum
import threed

pub fn main() {
  case argv.load().arguments {
    ["project2", first, second, third] -> {
      case int.parse(first) {
        Ok(result) -> {
          let nodes = result
          io.println("Number of Nodes: " <> int.to_string(nodes))
          // let args = []
          // let args = list.append(args, [nodes])

          let nodes = case second {
            "full" -> {
              io.println("topology is full")
              nodes
            }
            "3D" -> {
              io.println("topology is 3D")
              threed.number_of_3d_nodes(nodes)
            }
            "line" -> {
              io.println("topology is line")
              nodes
            }
            "imp3D" -> {
              io.println("topology is full")
              threed.number_of_3d_nodes(nodes)
            }
            _ -> {
              io.println("INVALID TOPOLOGY")
              nodes
            }
          }
          // let args = list.append(args, [second])

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
          // let args = list.append(args, [third])

          // set up actors
          let actors_dict = case third {
            // "gossip" -> {
            //   gossalg.initialize_gossip(1, nodes, dict.new())
            // }
            "push-sum" -> {
              pushsum.initialize_actors_push_sum(0, nodes, dict.new())
            }
            _ -> {
              io.println("INVALID ALGORITHM")
              dict.new()
            }
          }
          io.println(
            "Actors initialized: " <> int.to_string(dict.size(actors_dict)),
          )

          // set up topology
          case second {
            "full" -> {
              io.println("topology is full")
            }
            "3D" -> {
              io.println("topology is 3D")
              threed.setup_3d_topology(actors_dict)
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
        }
        _ -> io.println("n is not int")
      }
    }
    _ ->
      io.println("usage: gleam run project2 <numNodes> <topology> <algorithm>")
  }
}
