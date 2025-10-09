import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

// We will be implementing the Chord protocol for a distributed hash table. This file contains the code for each node.

// State holds the storage/variables of each node
pub type StateHolder(e) {
  StateHolder(
    id: Int,
    pred_id: Int,
    // each entry is (node_id, subject)
    finger_table: Dict(Int, process.Subject(NodeOperation(e))),
    // key value pairs representing the database
    storage: Dict(Int, Float),
    request_num: Int,
    max_num: Int,
    //parent_process: process.Subject(String),
    super: process.Subject(SuperMessage(e)),
  )
}

//-----------------------------------SUPERVISOR FUNCTIONS----------------------------------------------

// pub type RunMessage(e) {
//   Start(actor: process.Subject(NodeOperation(e)))
//   End
// }

pub type SuperMessage(e) {
  Run(num_nodes: Int, num_requests: Int)
  AddNode(num_requests: Int)
  Done
}

pub fn waiter(nodes: List(process.Subject(NodeOperation(e)))) {
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
  state: List(process.Subject(NodeOperation(e))),
  message: SuperMessage(e),
) -> actor.Next(List(process.Subject(NodeOperation(e))), SuperMessage(e)) {
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
  nodes: dict.Dict(Int, process.Subject(NodeOperation(e))),
  //parent: process.Subject(String),
  super: process.Subject(SuperMessage(e)),
) -> dict.Dict(Int, process.Subject(NodeOperation(e))) {
  case int.compare(num, max) {
    order.Lt -> {
      let initial_state = StateHolder(dict.new(), id, 0, max, super)
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(node_handler)
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

pub type NodeOperation(e) {
  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(NodeOperation(e)))
  ReceiveMessage(s: Float, w: Float)
  FindSuccessor(id: Int, caller: process.Subject(NodeOperation(e)), key: Int)
  ClosestPrecedingNode(
    id: Int,
    caller: process.Subject(NodeOperation(e)),
    key: Int,
  )
  CreateChordRing
  Join(existing: process.Subject(NodeOperation(e)))
  Stabilize
  Notify(potential_predecessor: process.Subject(NodeOperation(e)))
  FixFingers
  CheckPredecessor
  Finish
}

fn send_requests(from: process.Subject(NodeOperation(e)), num_requests: Int) {
  process.sleep(1000)

  //Send requests

  send_requests(from, num_requests - 1)
}

fn node_handler(
  state: StateHolder(e),
  message: NodeOperation(e),
) -> actor.Next(StateHolder(e), NodeOperation(e)) {
  case message {
    AddNeighbor(neighbor_id, neighbor) -> {
      let new_neighbors = dict.insert(state.neighbors, neighbor_id, neighbor)
      let new_state =
        StateHolder(state.id, state.request_num, state.max_num, state.super)
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
    Finish -> {
      process.send(state.super, Done)
      todo
    }
  }
}
