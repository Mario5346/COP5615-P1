import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/order
import gleam/otp/actor

pub fn initialize_actors_push_sum(
  start: Int,
  n: Int,
  nodes: Dict(Int, process.Subject),
) {
  case int.compare(start, n) {
    order.Gt -> []
    _ -> {
      let assert Ok(actor) =
        actor.new([]) |> actor.on_message(push_sum_handler) |> actor.start
      let subject = actor.data
      let new_nodes = insert(nodes, start, subject)

      let final = initialize_actors_push_sum(start + 1, n, new_nodes)
      final
    }
  }
}

pub type PushSumMessage(element) {
  Shutdown

  AddNeighbor(neighbor: process.Subject)

  ReceiveMessage(s: Float, w: Float)
}

fn push_sum_handler(
  state: #(List(process.Subject), #(Int, Int)),
  message: PushSumMessage(e),
) -> actor.Next(#(List(process.Subject), #(Int, Int)), PushSumMessage(e)) {
  case message {
    Shutdown -> {
      // io.println("Shutting down " <> int.to_string(state.id))
      process.exit(process.self(), "normal")
      state
    }
    AddNeighbor(neighbor) -> {
      // io.println("Adding neighbor to " <> int.to_string(state.id))
      let new_state = #(list.append(first(state), [neighbor]), second(state))
      actor.continue(new_state)
    }
    ReceiveMessage(s, w) -> {
      // io.println("Received message at " <> int.to_string(state.id))

      second(state)
    }
  }
}
