import argv
import full
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import gleam/time/timestamp
import gossalg
import imp3d
import line
import pushsum
import threed

fn check(subject: process.Subject(gossalg.Message(e))) {
  // process.sleep(10)
  let end = process.call(subject, 10_000, gossalg.Finished)
  // io.println("-----------------")

  case end {
    "NO" -> check(subject)
    _ -> end
  }
}

pub fn main() {
  case argv.load().arguments {
    ["project2", first, second, third] -> {
      case int.parse(first) {
        Ok(result) -> {
          let nodes = result
          io.println("Number of Nodes: " <> int.to_string(nodes))

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
              io.println("topology is imperfect 3D")
              threed.number_of_3d_nodes(nodes)
            }
            _ -> {
              io.println("INVALID TOPOLOGY")
              nodes
            }
          }

          case third {
            "gossip" -> {
              // set up actors
              let actors_dict = gossalg.initialize_gossip(1, nodes, dict.new())
              io.println(
                "Actors initialized: " <> int.to_string(dict.size(actors_dict)),
              )

              // set up topology
              case second {
                "full" -> {
                  full.full_network_gossip(1, actors_dict)
                }
                "3D" -> {
                  threed.setup_3d_topology_gossip(actors_dict)
                }
                "line" -> {
                  line.line_network_gossip(1, actors_dict)
                }
                "imp3D" -> {
                  imp3d.setup_imperfect_3d_topology_gossip(actors_dict)
                }
                _ -> {
                  io.println("INVALID TOPOLOGY")
                }
              }

              // start algorithm
              io.println("Starting gossip")
              let message = "this is my message"
              let assert Ok(first) = dict.get(actors_dict, 1)
              process.send(first, gossalg.Gossip(message))
              io.println("WAITING FOR ALGORITHM")
              let end = check(first)
              io.println("ALGORITHM DONE")
              io.println(end)
            }
            "push-sum" -> {
              let assert Ok(runner) =
                actor.new(timestamp.system_time())
                |> actor.on_message(pushsum.run_push_sum)
                |> actor.start
              let runner_subject = runner.data

              // set up actors
              let actors_dict =
                pushsum.initialize_actors_push_sum(
                  0,
                  nodes,
                  dict.new(),
                  runner_subject,
                )
              io.println(
                "Actors initialized: " <> int.to_string(dict.size(actors_dict)),
              )

              // set up topology
              case second {
                "full" -> {
                  full.full_network_pushsum(0, actors_dict)
                }
                "3D" -> {
                  threed.setup_3d_topology_pushsum(actors_dict)
                }
                "line" -> {
                  line.line_network_pushsum(0, actors_dict)
                }
                "imp3D" -> {
                  imp3d.setup_imperfect_3d_topology_pushsum(actors_dict)
                }
                _ -> {
                  io.println("INVALID TOPOLOGY")
                }
              }

              // start algorithm
              io.println("Starting push-sum")
              let first_actor = dict.get(actors_dict, 0)
              case first_actor {
                Ok(actor1) -> {
                  process.send(runner_subject, pushsum.Start(actor1))
                  process.sleep(1000)
                  Nil
                }
                Error(_e) -> {
                  io.println("Failed to get actor 0: " <> "\n")
                }
              }
            }
            _ -> {
              io.println("INVALID ALGORITHM")
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
