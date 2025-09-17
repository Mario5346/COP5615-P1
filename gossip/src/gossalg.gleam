import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/order
import gleam/otp/actor
import gleam/pair

pub type Message(e) {
  Shutdown

  AddNeighbor(neighbor: process.Subject(Result(e, Nil)))
  //   Sequence(start: Int, end: Int, k: Int)

  //   GetSequences(reply_with: process.Subject(Result(e, nil)))
}

fn gossip_handler(
  state: #(List(process.Subject(Result(e, Nil))), String),
  message: Message(e),
) -> actor.Next(#(List(process.Subject(Result(e, Nil))), String), Message(e)) {
  case message {
    Shutdown -> actor.stop()

    AddNeighbor(neighbor) -> {
      // io.println("Adding neighbor to " <> int.to_string(state.id))
      let new_state = #(list.append(pair.first(state), [neighbor]), "")
      actor.continue(new_state)
    }
    // Sequence(start, end, k) -> {
    //   case end {
    //     0 -> {
    //       //process.send(client, Error(Nil))
    //       actor.continue(state)
    //     }
    //     _ -> {
    //       let new_state = find_sequence(start, end, k, [])
    //       //process.send(client, Ok(new_state))
    //       actor.continue(new_state)
    //     }
    //   }
    // }
    // GetSequences(client) -> {
    //   actor.send(client, list)
    //   actor.continue(state)
    // }
  }
}

pub fn initialize_gossip(
  start: Int,
  num_nodes: Int,
  nodes: List(process.Subject(Result(element, Nil))),
) {
  case int.compare(start, num_nodes) {
    order.Gt -> []
    _ -> {
      let assert Ok(actor) =
        actor.new(#([], "")) |> actor.on_message(gossip_handler) |> actor.start
      let subject = actor.data
      let new_nodes = list.append(nodes, [subject])

      let final = initialize_gossip(start + 1, num_nodes, new_nodes)
      final
    }
  }
}
