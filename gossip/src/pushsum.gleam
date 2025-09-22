import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/order
import gleam/otp/actor

pub fn initialize_actors_push_sum(
  start: Int,
  n: Int,
  nodes: dict.Dict(Int, process.Subject(PushSumMessage(e))),
) -> dict.Dict(Int, process.Subject(PushSumMessage(e))) {
  case int.compare(start, n) {
    order.Lt -> {
      let initial_state =
        StateHolder(dict.new(), start, int.to_float(start), 1.0)
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(push_sum_handler)
        |> actor.start
      let subject = actor.data
      let new_nodes = dict.insert(nodes, start, subject)

      let final = initialize_actors_push_sum(start + 1, n, new_nodes)
      final
    }
    _ -> nodes
  }
}

pub type PushSumMessage(e) {
  Shutdown

  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(PushSumMessage(e)))

  ReceiveMessage(s: Float, w: Float)
}

pub type StateHolder(e) {
  StateHolder(
    neighbors: dict.Dict(Int, process.Subject(PushSumMessage(e))),
    id: Int,
    s: Float,
    w: Float,
  )
}

// state holds neighbors list and other information like id, s, w, etc.
fn push_sum_handler(
  state: StateHolder(e),
  message: PushSumMessage(e),
) -> actor.Next(StateHolder(e), PushSumMessage(e)) {
  case message {
    Shutdown -> {
      // io.println("Shutting down " <> int.to_string(state.id))
      actor.stop()
    }
    AddNeighbor(neighbor_id, neighbor) -> {
      // io.println("Adding neighbor to " <> int.to_string(state.id))
      let new_neighbors = dict.insert(state.neighbors, neighbor_id, neighbor)
      let new_state = StateHolder(new_neighbors, state.id, state.s, state.w)
      actor.continue(new_state)
    }
    ReceiveMessage(s, w) -> {
      // io.println("Received message at " <> int.to_string(state.id))

      actor.continue(state)
    }
  }
}
