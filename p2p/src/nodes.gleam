import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/otp/actor
import gleam/pair

// We will be implementing the Chord protocol for a distributed hash table. This file contains the code for each node.

pub type NodeInfo(e) {
  NodeInfo(id: Int, subject: process.Subject(NodeOperation(e)))
}

// State holds the storage/variables of each node
pub type StateHolder(e) {
  StateHolder(
    id: Int,
    pred: Option(NodeInfo(e)),
    // each entry is (index #(node_id, subject))
    finger_table: Dict(Int, NodeInfo(e)),
    // key value pairs representing the database
    storage: Dict(Int, Float),
    request_num: Int,
    max_num: Int,
    //parent_process: process.Subject(String), should just be main process
    super: process.Subject(NodeOperation(e)),
  )
}

// Loops n times to create n actors, each with its own state
pub fn initialize_actors(
  id: Int,
  pred_id: Int,
  loop_num: Int,
  max: Int,
  num_nodes: Int,
  nodes: dict.Dict(Int, process.Subject(NodeOperation(e))),
  //parent: process.Subject(String),
  super: process.Subject(NodeOperation(e)),
) -> dict.Dict(Int, process.Subject(NodeOperation(e))) {
  case int.compare(loop_num, max) {
    order.Lt -> {
      // Create new actor/node with a base state
      let initial_state =
        StateHolder(id, option.None, dict.new(), dict.new(), 0, max, super)
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(node_handler)
        |> actor.start
      let subject = actor.data
      // Add the new node to the list of nodes
      let new_nodes = dict.insert(nodes, loop_num, subject)

      let final =
        initialize_actors(
          id,
          pred_id,
          loop_num + 1,
          max,
          num_nodes,
          new_nodes,
          super,
        )
      final
    }
    _ -> nodes
  }
}

//----------------------------------------NODE FUNCTIONS----------------------------------------------

pub type NodeOperation(e) {
  AddNeighbor(neighbor_id: Int, neighbor: process.Subject(NodeOperation(e)))
  ReceiveMessage(s: Float, w: Float)
  FindSuccessor(id: Int, reply_with: process.Subject(NodeInfo(e)))
  ClosestPrecedingNode(id: Int, caller: process.Subject(NodeOperation(e)))
  CreateChordRing

  GetState(node: process.Subject(NodeOperation(e)))

  Join(existing: process.Subject(NodeOperation(e)))
  Stabilize
  Notify(potential_predecessor: process.Subject(NodeOperation(e)))
  FixFingers
  CheckPredecessor
  Finish
}

// create a new Chord ring.
fn create(state: StateHolder(e), node: process.Subject(NodeOperation(e))) {
  //predecessor := nil
  //successor := n
  let new_table =
    dict.insert(state.finger_table, state.id, NodeInfo(state.id, node))
  let new_state =
    StateHolder(
      state.id,
      option.None,
      new_table,
      state.storage,
      state.request_num,
      state.max_num,
      state.super,
    )
  new_state
}

// ask node n to find the successor of id
fn find_successor(
  state: StateHolder(e),
  node: process.Subject(NodeOperation(e)),
  id: Int,
) -> NodeInfo(e) {
  // // Yes, that should be a closing square bracket to match the opening parenthesis.
  // // It is a half closed interval.
  // if id ∈ (n, successor] then
  //     return successor
  // else
  //     // forward the query around the circle
  //     n0 := closest_preceding_node(id)
  //     return n0.find_successor(id)

  //GET FIRST ENTRY OF FINGER TABLE IDK HOW 
  let assert Ok(successor) = dict.get(state.finger_table, state.id + 1)
  let succ_id = successor.id
  let in_range = { id <= succ_id } && { id > state.id }

  case in_range {
    True -> {
      successor
    }
    False -> {
      let n0 = closest_preceding_node(state, node, id)
      process.call(n0.subject, 1000, FindSuccessor(id, reply_with: todo))
    }
  }
}

//helper loop for closest_preceeding_node
fn search_table(curr: Int, state: StateHolder(e), id: Int) {
  let table = state.finger_table

  case int.compare(curr, 0) {
    order.Gt -> {
      let assert Ok(finger) = dict.get(table, curr)
      let finger_id = pair.first(finger)
      let in_range = { finger_id > state.id } && { finger_id < id }
      case in_range {
        True -> {
          //let assert Ok(finger) = dict.get(table, curr)
          finger_id
        }
        _ -> search_table(curr - 1, state, id)
      }
    }
    _ -> state.id
  }
}

// search the local table for the highest predecessor of id, returns pred id
fn closest_preceding_node(
  state: StateHolder(e),
  node: process.Subject(NodeOperation(e)),
  id: Int,
) -> NodeInfo(e) {
  // for i = m downto 1 do
  //     if (finger[i] ∈ (n, id)) then
  //         return finger[i]
  // return n
  search_table(dict.size(state.finger_table), state, id)
}

// join a node n into a Chord ring containing node n'.
// To fix
fn join(state: StateHolder(e), known_node: process.Subject(NodeOperation(e))) {
  //  predecessor := nil;
  //  successor := n'.find successor(n);
  let predecessor = option.None
  let new_successor = find_successor(state, known_node, state.id)
  let new_state =
    StateHolder(
      state.id,
      predecessor,
      state.finger_table,
      state.storage,
      state.request_num,
      state.max_num,
      state.super,
    )
  new_state
}

// // called periodically. n asks the successor
// // about its predecessor, verifies if n's immediate
// // successor is consistent, and tells the successor about n
// fn stabilize(){
//       x = successor.predecessor
//     if x ∈ (n, successor) then
//         successor := x
//     successor.notify(n)
// }

// // n' thinks it might be our predecessor.
// fn notify(n'){
//     if predecessor is nil or n'∈(predecessor, n) then
//         predecessor := n'
// }

// // called periodically. refreshes finger table entries.
// // next stores the index of the finger to fix
// fn fix_fingers(){
//     next := next + 1
//     if next > m then
//         next := 1
//     finger[next] := find_successor(n+2next-1);
// }

fn send_requests(from: process.Subject(NodeOperation(e)), num_requests: Int) {
  todo
  //process.sleep(1000)

  //Send requests

  //send_requests(from, num_requests - 1)
}

pub fn node_handler(
  state: StateHolder(e),
  message: NodeOperation(e),
) -> actor.Next(StateHolder(e), NodeOperation(e)) {
  case message {
    AddNeighbor(neighbor_id, neighbor) -> {
      //Modifies Finger table

      //let new_neighbors = dict.insert(state.neighbors, neighbor_id, neighbor)
      let new_state =
        StateHolder(
          state.id,
          state.pred,
          state.finger_table,
          state.storage,
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
      actor.continue(state)
    }
    FindSuccessor(id, reply_with) -> {
      let result = find_successor(state, self, id)
      process.send(reply_with, result)
      actor.continue(state)
    }
    Finish -> {
      process.send(state.super, Finish)
      actor.continue(state)
    }
    _ -> {
      actor.continue(state)
    }
  }
}
