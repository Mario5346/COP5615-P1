import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor
import gleam/pair
import gleam/time/duration
import gleam/time/timestamp

pub fn initialize_actors_push_sum(
  start: Int,
  n: Int,
  nodes: dict.Dict(Int, process.Subject(PushSumMessage(e))),
  runner: process.Subject(RunPushSumMessage(e)),
) -> dict.Dict(Int, process.Subject(PushSumMessage(e))) {
  case int.compare(start, n) {
    order.Lt -> {
      let initial_state =
        StateHolder(dict.new(), start, int.to_float(start), 1.0, runner)
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(push_sum_handler)
        |> actor.start
      let subject = actor.data
      let new_nodes = dict.insert(nodes, start, subject)

      let final = initialize_actors_push_sum(start + 1, n, new_nodes, runner)
      final
    }
    _ -> nodes
  }
}

pub type RunPushSumMessage(e) {
  Start(actor: process.Subject(PushSumMessage(e)))
  End
}

pub fn run_push_sum(
  state: timestamp.Timestamp,
  message: RunPushSumMessage(e),
) -> actor.Next(timestamp.Timestamp, RunPushSumMessage(e)) {
  case message {
    Start(actor) -> {
      let start = timestamp.system_time()
      process.send(actor, ReceiveMessage(0.1, 0.1))
      io.println("Sent initial message to actor 0")
      actor.continue(start)
    }
    End -> {
      let end = timestamp.system_time()
      let elapsed =
        duration.to_seconds_and_nanoseconds(timestamp.difference(state, end))
      io.println(
        "Time taken: "
        <> int.to_string(pair.first(elapsed))
        <> " s "
        <> int.to_string(pair.second(elapsed))
        <> " ns",
      )
      actor.stop()
    }
  }
}

pub type PushSumMessage(e) {
  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(PushSumMessage(e)))
  ReceiveMessage(s: Float, w: Float)
  GetNeighbors(
    reply_to: process.Subject(
      dict.Dict(Int, process.Subject(PushSumMessage(e))),
    ),
  )
}

pub type StateHolder(e) {
  StateHolder(
    neighbors: dict.Dict(Int, process.Subject(PushSumMessage(e))),
    id: Int,
    s: Float,
    w: Float,
    end_subject: process.Subject(RunPushSumMessage(e)),
  )
}

// state holds neighbors list and other information like id, s, w, etc.
fn push_sum_handler(
  state: StateHolder(e),
  message: PushSumMessage(e),
) -> actor.Next(StateHolder(e), PushSumMessage(e)) {
  case message {
    AddNeighbor(neighbor_id, neighbor) -> {
      let new_neighbors = dict.insert(state.neighbors, neighbor_id, neighbor)
      let new_state =
        StateHolder(
          new_neighbors,
          state.id,
          state.s,
          state.w,
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
      // io.println(
      //   "Received message at node "
      //   <> int.to_string(state.id)
      //   <> ". s, w = "
      //   <> float.to_string(s)
      //   <> ", "
      //   <> float.to_string(w),
      // )
      // update s and w
      let new_s = state.s +. s
      let new_w = state.w +. w
      let ratio = new_s /. new_w
      let difference = float.absolute_value(ratio -. { state.s /. state.w })

      // termination condition
      case float.compare(difference, 1.0e-10) {
        order.Lt -> {
          io.println(
            "Node "
            <> int.to_string(state.id)
            <> " has converged with ratio: "
            <> float.to_string(ratio)
            <> "\n",
          )
          process.send(state.end_subject, End)
          actor.stop()
        }
        _ -> {
          // send half to a random neighbor
          let half_s = new_s /. 2.0
          let half_w = new_w /. 2.0
          let selected = random_element(dict.keys(state.neighbors))
          let subject = state.neighbors |> dict.get(selected)
          // io.println(
          //   float.to_string(difference)
          //   <> " neighbors: "
          //   <> int.to_string(dict.size(state.neighbors))
          //   <> " selected: "
          //   <> int.to_string(selected),
          // )
          case subject {
            Ok(result) -> {
              actor.send(result, ReceiveMessage(half_s, half_w))
              // io.print(
              //   "sent message to neighbor: "
              //   <> int.to_string(selected)
              //   <> " from node: "
              //   <> int.to_string(state.id)
              //   <> "\n",
              // )
            }
            Error(_e) -> {
              io.print(
                "Failed to get neighbor at " <> int.to_string(state.id) <> "\n",
              )
            }
          }
          let new_state =
            StateHolder(
              state.neighbors,
              state.id,
              half_s,
              half_w,
              state.end_subject,
            )
          actor.continue(new_state)
        }
      }
    }
    GetNeighbors(reply_to) -> {
      process.send(reply_to, state.neighbors)
      actor.continue(state)
    }
  }
}

pub fn random_element(l: List(Int)) -> Int {
  case l {
    [] -> 0
    _ -> {
      case list.first(list.sample(l, 1)) {
        Ok(x) -> x
        _ -> 0
      }
    }
  }
}
