import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gossalg
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
          let actors_list = []
          case third {
            "gossip" -> {
              let actors_list = gossalg.initialize_gossip(1, nodes, [])
            }
            "push-sum" -> {
              let actors_list = pushsum.initialize_actors_push_sum(1, nodes, [])
            }
            _ -> {
              io.println("INVALID ALGORITHM")
            }
          }
          io.println(
            "Actors initialized: " <> int.to_string(list.length(actors_list)),
          )

          // set up topology
          case second {
            "full" -> {
              io.println("topology is full")
            }
            "3D" -> {
              io.println("topology is 3D")
              threed.setup_3d_topology(actors_list)
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
