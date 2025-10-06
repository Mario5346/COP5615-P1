import argv
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

pub type RunMessage(e) {
  Start(actor: process.Subject(Message(e)))
  End
}

pub fn initialize_actor(
  id: Int,
  num: Int,
  max: Int,
  nodes: dict.Dict(Int, process.Subject(Message(e))),
  runner: process.Subject(RunMessage(e)),
) -> dict.Dict(Int, process.Subject(Message(e))) {
  case int.compare(num, max) {
    order.Lt -> {
      let initial_state = StateHolder(dict.new(), id, 0, max, runner)
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(handler)
        |> actor.start
      let subject = actor.data
      let new_nodes = dict.insert(nodes, num, subject)

      let final = initialize_actor(id, num + 1, max, new_nodes, runner)
      final
    }
    _ -> nodes
  }
}

pub type Message(e) {
  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(Message(e)))
  ReceiveMessage(s: Float, w: Float)
  GetNeighbors(
    reply_to: process.Subject(dict.Dict(Int, process.Subject(Message(e)))),
  )
}

pub type StateHolder(e) {
  StateHolder(
    neighbors: dict.Dict(Int, process.Subject(Message(e))),
    id: Int,
    request_num: Int,
    max_num: Int,
    end_subject: process.Subject(RunMessage(e)),
  )
}

fn handler(
  state: StateHolder(e),
  message: Message(e),
) -> actor.Next(StateHolder(e), Message(e)) {
  case message {
    AddNeighbor(neighbor_id, neighbor) -> {
      let new_neighbors = dict.insert(state.neighbors, neighbor_id, neighbor)
      let new_state =
        StateHolder(
          new_neighbors,
          state.id,
          state.request_num,
          state.max_num,
          state.end_subject,
        )
      // io.println(
      //   "Adding neighbor to "
      //   <> int.to_string(state.id)
      //   <> "new size: "
      //   <> int.to_string(dict.size(new_neighbors)),
      // )
      actor.continue(new_state)
    }
    ReceiveMessage(s, w) -> {
      todo
      //TODO
    }

    GetNeighbors(reply_to) -> {
      process.send(reply_to, state.neighbors)
      actor.continue(state)
    }
  }
}
