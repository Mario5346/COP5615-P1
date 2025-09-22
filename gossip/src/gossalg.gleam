import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/order
import gleam/otp/actor
import gleam/pair

pub type Message(e) {
  Shutdown

  AddNeighbor(neighbor: process.Subject(Message(e)))
  GetNeighbors(
    reply_to: process.Subject(dict.Dict(Int, process.Subject(Message(e)))),
  )
  // RegisterActor(neighbor: process.Subject(Message(e)))
  Gossip(message: String)

  Finished(parent: process.Subject(String))
}

fn gossip_handler(
  state: #(dict.Dict(Int, process.Subject(Message(e))), Int),
  message: Message(e),
) -> actor.Next(#(dict.Dict(Int, process.Subject(Message(e))), Int), Message(e)) {
  let number_of_messages = 10
  let finished_state = number_of_messages + 1

  case message {
    Shutdown -> actor.stop()

    AddNeighbor(neighbor) -> {
      // io.println("Adding neighbor to " <> int.to_string(state.id))
      let new_state = #(
        pair.first(state)
          |> dict.insert(dict.size(pair.first(state)) + 1, neighbor),
        pair.second(state),
      )
      // io.print("added neighbor")
      // echo dict.size(pair.first(state))
      actor.continue(new_state)
    }

    GetNeighbors(reply_to) -> {
      process.send(reply_to, pair.first(state))
      actor.continue(state)
    }

    Gossip(message) -> {
      let max = dict.size(pair.first(state))
      let selected = int.random(max - 1) + 1
      let subject = pair.first(state) |> dict.get(selected)
      //io.println(" SELECTED: " <> int.to_string(selected))
      let count = pair.second(state) + 1
      let new_state = pair.new(pair.first(state), count)
      case count {
        number_of_messages -> {
          dict.each(pair.first(state), fn(k, v) {
            actor.send(v, Gossip("STOP"))
          })
          let final_state = pair.new(pair.first(state), finished_state)
          actor.continue(final_state)
        }
        finished_state -> {
          actor.continue(state)
        }
        _ -> {
          case message {
            "STOP" -> {
              dict.each(pair.first(state), fn(k, v) {
                actor.send(v, Gossip("STOP"))
              })
              let final_state = pair.new(pair.first(state), finished_state)
              actor.continue(final_state)
            }
            _ -> {
              case subject {
                Ok(result) -> {
                  actor.send(result, Gossip(message))
                  // io.println(
                  //   "sent message to neighbor: " <> int.to_string(selected),
                  // )
                  //echo pair.second(new_state)
                  actor.continue(new_state)
                }
                Error(e) -> {
                  // actor.send(process.new_subject(), message)
                  io.println("ERROR HERE")
                  actor.continue(new_state)
                }
              }
              actor.continue(new_state)
            }
          }
        }
      }
    }
    Finished(parent) -> {
      case pair.second(state) {
        finished_state -> {
          io.println(" STATE " <> int.to_string(pair.second(state)))
          actor.send(parent, "Actor has Finished")
          actor.continue(state)
        }
        _ -> {
          actor.send(parent, "NO")
          actor.continue(state)
        }
      }
    }
    // RegisterActor(client) -> {
    //   let subject = process.new_subject()
    //   actor.send(client, subject)
    //   actor.continue(#([], ""))
    // }
  }
}

// pub fn register_actor(
//   client: process.Subject(process.Subject(Result(e, Nil))),
// ) -> actor.Next(process.Subject(process.Subject(Result(e, Nil))), Message(e)) {
//   let subject = process.new_subject()
//   actor.send(client, subject)
//   actor.continue(client)
// }

pub fn initialize_gossip(
  start: Int,
  num_nodes: Int,
  nodes: dict.Dict(Int, process.Subject(Message(e))),
) {
  case int.compare(start, num_nodes) {
    order.Gt -> dict.new()
    _ -> {
      //io.print("INITIALIZING GOSSIP   ")
      let subject = process.new_subject()
      let assert Ok(actor) =
        actor.new(#(dict.new(), 0))
        |> actor.on_message(gossip_handler)
        |> actor.start
      let sub = actor.data
      //process.send(sub, AddNeighbor(subject))
      //process.send(subject, RegisterActor(subject))

      let new_nodes = initialize_gossip(start + 1, num_nodes, nodes)
      // new_nodes |> dict.insert(start, sub)
      let final = dict.insert(new_nodes, start, sub)

      //echo new_nodes
      final
    }
  }
}
// fn set_neighbors(node: process.Subject(Message(e)), nodes: dict.Dict(Int, process.Subject(Message(e)))){

// }
