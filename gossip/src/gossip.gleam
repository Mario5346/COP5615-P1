import argv
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor

// import gleam/list
// import gleam/otp/actor
// import gleam/time/duration
// import gleam/time/timestamp
import gossalg
<<<<<<< HEAD

// import pushsum
import threed

@external(erlang, "maps", "new")
pub fn new() -> dict.Dict(k, v)

fn check(subject: process.Subject(gossalg.Message(e))) {
  // process.sleep(10)
  let end = process.call(subject, 10_000, gossalg.Finished)
  // io.println("-----------------")

  case end {
    "NO" -> check(subject)
    _ -> end
  }
}

=======
import imp3d
import pushsum
import threed

>>>>>>> 58d4aea4372531481a73e27d8e55a8ca1124c8c4
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
            // "3D" -> {
            //   io.println("topology is 3D")
            //   threed.number_of_3d_nodes(nodes)
            // }
            "line" -> {
              io.println("topology is line")
              nodes
            }
            // "imp3D" -> {
            //   io.println("topology is full")
            //   threed.number_of_3d_nodes(nodes)
            // }
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
<<<<<<< HEAD
            "gossip" -> {
              gossalg.initialize_gossip(1, nodes, new())
            }
            // "push-sum" -> {
            //   pushsum.initialize_actors_push_sum(1, nodes, new())
            // }
=======
            // "gossip" -> {
            //   gossalg.initialize_gossip(1, nodes, dict.new())
            // }
            "push-sum" -> {
              pushsum.initialize_actors_push_sum(0, nodes, dict.new())
            }
>>>>>>> 58d4aea4372531481a73e27d8e55a8ca1124c8c4
            _ -> {
              io.println("INVALID ALGORITHM")
              dict.new()
            }
          }
          io.println(
            "Actors initialized: " <> int.to_string(dict.size(actors_dict)),
          )
<<<<<<< HEAD
          //echo actors_dict
=======
>>>>>>> 58d4aea4372531481a73e27d8e55a8ca1124c8c4

          // set up topology
          case second {
            "full" -> {
              gossalg.full_network(1, actors_dict)
              io.println("topology is full")
            }
<<<<<<< HEAD
            // "3D" -> {
            //   io.println("topology is 3D")
            //   threed.setup_3d_topology(actors_list)
            // }
=======
            "3D" -> {
              io.println("topology is 3D")
              threed.setup_3d_topology(actors_dict)
            }
>>>>>>> 58d4aea4372531481a73e27d8e55a8ca1124c8c4
            "line" -> {
              gossalg.line_network(1, actors_dict)
              io.println("topology is line")
            }
            "imp3D" -> {
              io.println("topology is full")
            }
            _ -> {
              io.println("INVALID TOPOLOGY")
            }
          }
          io.println("STARTING ALGORITHM")
          let message = "this is my message"
          let assert Ok(first) = dict.get(actors_dict, 1)
          // case getter {
          //   Ok(first) -> process.send(first, gossalg.Gossip(message))
          //   Error(_) -> Nil
          // }
          process.send(first, gossalg.Gossip(message))
          io.println("WAITING FOR ALGORITHM")
          //let end = process.call(first, 1000, gossalg.Finished)
          let end = check(first)
          io.println("ALGORITHM DONE")
          //dict.each(actors_dict, fn(k, v) { actor.send(v, gossalg.Shutdown) })
          io.println(end)
        }
        _ -> io.println("n is not int")
      }
    }
    _ ->
      io.println("usage: gleam run project2 <numNodes> <topology> <algorithm>")
  }
}
