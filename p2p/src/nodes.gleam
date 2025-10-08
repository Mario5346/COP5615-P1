import argv
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

pub type StateHolder(e) {
  StateHolder(
    neighbors: dict.Dict(Int, process.Subject(Message(e))),
    id: Int,
    request_num: Int,
    max_num: Int,
    //parent_process: process.Subject(String),
    super: process.Subject(SuperMessage(e)),
  )
}

//-----------------------------------SUPERVISOR FUNCTIONS----------------------------------------------

// pub type RunMessage(e) {
//   Start(actor: process.Subject(Message(e)))
//   End
// }

pub type SuperMessage(e) {
  Run(num_nodes: Int, num_requests: Int)
  AddNode(num_requests: Int)
  Done
}

pub fn waiter(nodes: List(process.Subject(Message(e)))) {
  case list.first(nodes) {
    Ok(sub) -> {
      process.receive_forever(sub)
      io.println("node has finished")
      let new_nodes = case nodes {
        [_, ..rest] -> rest
        _ -> []
      }
      waiter(new_nodes)
    }
    _ -> {
      io.println("All nodes have finished")
    }
  }
}

pub fn super_handler(
  state: List(process.Subject(Message(e))),
  message: SuperMessage(e),
) -> actor.Next(List(process.Subject(Message(e))), SuperMessage(e)) {
  case message {
    Run(n, k) -> {
      //Initialize nodes

      // Wait for nodes to finish
      case list.first(state) {
        Ok(sub) -> {
          waiter(state)
          actor.continue(state)
        }
        _ -> {
          todo
        }
      }
    }
    AddNode(num_requests) -> {
      //Adds node to network, making it a neighbor to the necessary nodes and adding to node list
      todo
    }
    Done -> {
      io.println("node done")
      actor.continue(state)
    }
  }
}

pub fn initialize_actors(
  id: Int,
  num: Int,
  max: Int,
  nodes: dict.Dict(Int, process.Subject(Message(e))),
  //parent: process.Subject(String),
  super: process.Subject(SuperMessage(e)),
) -> dict.Dict(Int, process.Subject(Message(e))) {
  case int.compare(num, max) {
    order.Lt -> {
      let initial_state = StateHolder(dict.new(), id, 0, max, super)
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(handler)
        |> actor.start
      let subject = actor.data
      let new_nodes = dict.insert(nodes, num, subject)

      let final = initialize_actors(id, num + 1, max, new_nodes, super)
      final
    }
    _ -> nodes
  }
}

//----------------------------------------NODE FUNCTIONS----------------------------------------------

pub type Message(e) {
  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(Message(e)))
  ReceiveMessage(s: Float, w: Float)
  GetNeighbors(
    reply_to: process.Subject(dict.Dict(Int, process.Subject(Message(e)))),
  )
  Finish
}

fn send_requests(from: process.Subject(Message(e)), num_requests: Int) {
  process.sleep(1000)

  //Send requests

  send_requests(from, num_requests - 1)
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
          state.super,
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

    Finish -> {
      process.send(state.super, Done)
      todo
    }
  }
}
