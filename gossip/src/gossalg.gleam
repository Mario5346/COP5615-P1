import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/order
import gleam/otp/actor
import gleam/otp/supervision
import gleam/pair

pub type Message(e) {
  Shutdown

  AddNeighbor(neighbor: process.Subject(Result(e, Nil)))

  RegisterActor(neighbor: process.Subject(Message(e)))
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

    RegisterActor(client) -> {
      let subject = process.new_subject()
      actor.send(client, Message(subject))
      actor.continue(#([], ""))
    }
  }
}

pub fn register_actor(
  client: process.Subject(process.Subject(Result(e, Nil))),
) -> actor.Next(process.Subject(process.Subject(Result(e, Nil))), Message(e)) {
  let subject = process.new_subject()
  actor.send(client, subject)
  actor.continue(client)
}

pub fn initialize_gossip(
  start: Int,
  num_nodes: Int,
  nodes: List(process.Subject(Result(element, Nil))),
) {
  case int.compare(start, num_nodes) {
    order.Gt -> []
    _ -> {
      let subject = process.new_subject()
      let assert Ok(actor) =
        actor.new(#([], "")) |> actor.on_message(gossip_handler) |> actor.start
      process.send(subject, RegisterActor(subject))

      //let new_nodes = list.append(nodes, [subject])

      let final = initialize_gossip(start + 1, num_nodes, new_nodes)
      final
    }
  }
}
