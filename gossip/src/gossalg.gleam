import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/order
import gleam/otp/actor
import gleam/pair

pub type Message(e) {
  Shutdown

  AddNeighbor(neighbor: process.Subject(Message(e)))

  // RegisterActor(neighbor: process.Subject(Message(e)))
  Gossip(message: Message(e))
}

fn gossip_handler(
  state: #(dict.Dict(Int, process.Subject(Message(e))), Int),
  message: Message(e),
) -> actor.Next(#(dict.Dict(Int, process.Subject(Message(e))), Int), Message(e)) {
  case message {
    Shutdown -> actor.stop()

    AddNeighbor(neighbor) -> {
      // io.println("Adding neighbor to " <> int.to_string(state.id))
      let new_state = #(
        pair.first(state)
          |> dict.insert(dict.size(pair.first(state)) + 1, neighbor),
        pair.second(state),
      )
      actor.continue(new_state)
    }

    Gossip(message) -> {
      let selected = int.random(dict.size(pair.first(state)))
      let subject = pair.first(state) |> dict.get(selected)
      case subject {
        Ok(result) -> actor.send(result, message)
        Error(e) -> actor.send(process.new_subject(), message)
      }

      actor.continue(state)
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
      let subject = process.new_subject()
      let assert Ok(actor) =
        actor.new(#(dict.new(), 0))
        |> actor.on_message(gossip_handler)
        |> actor.start
      let sub = actor.data
      //process.send(sub, AddNeighbor(subject))
      //process.send(subject, RegisterActor(subject))

      let new_nodes = initialize_gossip(start + 1, num_nodes, nodes)

      new_nodes |> dict.insert(start, sub)
      new_nodes
    }
  }
}

// fn set_neighbors(node: process.Subject(Message(e)), nodes: dict.Dict(Int, process.Subject(Message(e)))){

// }

fn full_network(start: Int, nodes: dict.Dict(Int, process.Subject(Message(e)))) {
  case int.compare(start + 1, dict.size(nodes)) {
    order.Gt -> Nil
    _ -> {
      let curr = start
      dict.each(nodes, fn(k, v) {
        case k {
          start -> Nil
          _ -> {
            let subject = nodes |> dict.get(start)
            case subject {
              Ok(result) -> process.send(result, AddNeighbor(v))
              Error(e) -> Nil
            }
          }
        }
      })
      full_network(start + 1, nodes)
    }
  }
}

fn line_network(start: Int, nodes: dict.Dict(Int, process.Subject(Message(e)))) {
  case int.compare(start + 1, dict.size(nodes)) {
    order.Gt -> Nil
    _ -> {
      let curr = start
      let left = nodes |> dict.get(start - 1)
      let right = nodes |> dict.get(start + 1)
      let subject = nodes |> dict.get(start)

      case subject {
        Ok(result) -> {
          case left {
            Ok(l) -> process.send(result, AddNeighbor(l))
            Error(e) -> Nil
          }
          case right {
            Ok(r) -> process.send(result, AddNeighbor(r))
            Error(e) -> Nil
          }
        }
        Error(e) -> Nil
      }
      line_network(start + 1, nodes)
    }
  }
}
