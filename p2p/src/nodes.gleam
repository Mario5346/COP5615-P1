import gleam/bit_array
import gleam/bytes_tree
import gleam/crypto.{Sha1}
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/option.{type Option}
import gleam/order
import gleam/otp/actor

// We will be implementing the Chord protocol for a distributed hash table. This file contains the code for each node.

pub type NodeInfo(e) {
  NodeInfo(id: Int, subject: process.Subject(NodeOperation(e)))
}

// State holds the storage/variables of each node
pub type StateHolder(e) {
  StateHolder(
    id: Int,
    self_subject: Option(process.Subject(NodeOperation(e))),
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
        StateHolder(
          loop_num,
          option.None,
          option.None,
          dict.new(),
          dict.new(),
          0,
          max,
          super,
        )
      let assert Ok(actor) =
        actor.new(initial_state)
        |> actor.on_message(node_handler)
        |> actor.start
      let subject = actor.data
      // TODO: ID should be hash of IP address
      actor.send(subject, AddSelfInfo(subject))
      case loop_num {
        0 -> actor.send(subject, CreateChordRing)
        _ -> {
          let assert Ok(node) = dict.get(nodes, 0)
          actor.send(subject, Join(node))
        }
      }

      // Todo: Call Create Chord Ring on first node and Join on the rest

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

fn in_open_closed_interval(x: Int, a: Int, b: Int) -> Bool {
  let x_hash = crypto.hash(Sha1, <<x>>)
  let a_hash = crypto.hash(Sha1, <<a>>)
  let b_hash = crypto.hash(Sha1, <<b>>)

  case bit_array.compare(a_hash, b_hash) {
    order.Gt -> {
      // wrap around case. { x > a && x > b } || { x < a && x <= b }
      case bit_array.compare(x_hash, a_hash) {
        order.Lt -> {
          case bit_array.compare(x_hash, b_hash) {
            order.Gt -> False
            _ -> True
          }
        }
        order.Gt -> {
          case bit_array.compare(x_hash, b_hash) {
            order.Gt -> True
            _ -> False
          }
        }
        _ -> False
      }
    }
    // { x > a } && { x <= b }
    _ -> {
      case bit_array.compare(x_hash, a_hash) {
        order.Gt -> {
          case bit_array.compare(x_hash, b_hash) {
            order.Gt -> False
            _ -> True
          }
        }
        _ -> False
      }
    }
  }
}

fn in_open_interval(x: Int, a: Int, b: Int) -> Bool {
  let x_hash = crypto.hash(Sha1, <<x>>)
  let a_hash = crypto.hash(Sha1, <<a>>)
  let b_hash = crypto.hash(Sha1, <<b>>)

  case bit_array.compare(a_hash, b_hash) {
    order.Gt -> {
      // wrap around case. { x > a && x > b } || { x < a && x < b }
      case bit_array.compare(x_hash, a_hash) {
        order.Lt -> {
          case bit_array.compare(x_hash, b_hash) {
            order.Lt -> True
            _ -> False
          }
        }
        order.Gt -> {
          case bit_array.compare(x_hash, b_hash) {
            order.Gt -> True
            _ -> False
          }
        }
        _ -> False
      }
    }
    // { x > a } && { x < b }
    _ -> {
      case bit_array.compare(x_hash, a_hash) {
        order.Gt -> {
          case bit_array.compare(x_hash, b_hash) {
            order.Lt -> True
            _ -> False
          }
        }
        _ -> False
      }
    }
  }
}

//----------------------------------------NODE FUNCTIONS----------------------------------------------

pub type NodeOperation(e) {
  SearchKey(key: Int, reply_with: process.Subject(Float), jump: Int)
  AddKeyToRing(
    key: Int,
    value: Float,
    reply_with: process.Subject(Int),
    jump_num: Int,
  )
  FindSuccessor(
    id: Int,
    reply_with: process.Subject(NodeInfo(e)),
    jump_num: Int,
  )
  CreateChordRing

  GetState(reply_with: process.Subject(StateHolder(e)))
  AddSelfInfo(info: process.Subject(NodeOperation(e)))
  HopNumber(reply_with: process.Subject(Int), number: Int)

  // private
  AddKeyToStorage(key: Int, value: Float)
  Join(n0: process.Subject(NodeOperation(e)))
  Stabilize
  Notify(potential_predecessor: NodeInfo(e))
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
      state.self_subject,
      option.None,
      new_table,
      state.storage,
      state.request_num,
      state.max_num,
      state.super,
    )
  new_state
}

// ask node n to find the successor of id. State represents n. id can be either a key or a node id.
fn find_successor(state: StateHolder(e), id: Int, jump_num: Int) -> NodeInfo(e) {
  // if id ∈ (n, successor] then
  //     return successor
  // else
  //     // forward the query around the circle
  //     n0 := closest_preceding_node(id)
  //     return n0.find_successor(id)

  //GET FIRST ENTRY OF FINGER TABLE IDK HOW 
  let assert Ok(successor) = dict.get(state.finger_table, state.id + 1)
  let succ_id = successor.id
  // automatically handles hashing
  let in_range = in_open_closed_interval(id, state.id, succ_id)

  case in_range {
    True -> {
      successor
    }
    False -> {
      let n0 = closest_preceding_node(state, id)
      process.call(n0.subject, 1000, FindSuccessor(id, _, jump_num + 1))
    }
  }
}

//helper loop for closest_preceeding_node
fn search_table(curr: Int, state: StateHolder(e), id: Int) -> NodeInfo(e) {
  let table = state.finger_table

  case int.compare(curr, 0) {
    order.Gt -> {
      let assert Ok(finger) = dict.get(table, curr)
      let finger_id = finger.id
      // automatically handles hashing
      let in_range = in_open_interval(finger_id, state.id, id)
      case in_range {
        True -> {
          //let assert Ok(finger) = dict.get(table, curr)
          finger
        }
        _ -> search_table(curr - 1, state, id)
      }
    }
    _ -> {
      // return n. Assuming self subject is always present
      case state.self_subject {
        option.Some(subject) -> NodeInfo(state.id, subject)
        option.None -> NodeInfo(state.id, process.new_subject())
      }
    }
  }
}

// search the local table for the highest predecessor of id, returns pred id
fn closest_preceding_node(state: StateHolder(e), id: Int) -> NodeInfo(e) {
  // for i = m downto 1 do
  //     if (finger[i] ∈ (n, id)) then
  //         return finger[i]
  // return n
  search_table(dict.size(state.finger_table), state, id)
}

// join the current node n into a Chord ring containing node n'.
// To fix
fn join(
  state: StateHolder(e),
  existing_chord_node: process.Subject(NodeOperation(e)),
) {
  //  predecessor := nil;
  //  successor := n'.find successor(n);
  let predecessor = option.None
  let new_successor =
    process.call(existing_chord_node, 1000, FindSuccessor(state.id, _, 0))
  // replace entry for successor in finger table
  let new_table =
    dict.delete(state.finger_table, state.id + 1)
    |> dict.insert(state.id + 1, new_successor)

  let new_state =
    StateHolder(
      state.id,
      state.self_subject,
      predecessor,
      new_table,
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
fn stabilize(state: StateHolder(e)) {
  // x = successor.predecessor
  // if x ∈ (n, successor) then
  //     successor := x
  // successor.notify(n)
  let successor = dict.get(state.finger_table, state.id + 1)
  case successor {
    Ok(succ) -> {
      let successor_state = process.call(succ.subject, 1000, GetState)
      let x = successor_state.pred
      case x {
        option.Some(node) -> {
          let x_id = node.id
          let in_range = in_open_interval(x_id, state.id, succ.id)
          case in_range {
            // Update successor to x
            True -> {
              let new_successor = node
              let new_table =
                dict.delete(state.finger_table, state.id + 1)
                |> dict.insert(state.id + 1, new_successor)
              let new_state =
                StateHolder(
                  state.id,
                  state.self_subject,
                  state.pred,
                  new_table,
                  state.storage,
                  state.request_num,
                  state.max_num,
                  state.super,
                )
              case state.self_subject {
                option.Some(subject) ->
                  process.send(
                    succ.subject,
                    Notify(NodeInfo(state.id, subject)),
                  )
                _ -> Nil
              }
              new_state
            }
            // Do not update successor. Just notify
            _ -> {
              case state.self_subject {
                option.Some(subject) ->
                  process.send(
                    succ.subject,
                    Notify(NodeInfo(state.id, subject)),
                  )
                _ -> Nil
              }
              state
            }
          }
        }
        // successor's predecessor is nil. Notify successor to update.
        _ -> {
          case state.self_subject {
            option.Some(subject) ->
              process.send(succ.subject, Notify(NodeInfo(state.id, subject)))
            _ -> Nil
          }
          state
        }
      }
    }
    _ -> {
      // Should not happen. No successor
      state
    }
  }
}

// n' thinks it might be our predecessor, so we update our predecessor.
fn notify(state: StateHolder(e), n0: NodeInfo(e)) -> StateHolder(e) {
  //     if predecessor is nil or n'∈(predecessor, n) then
  //         predecessor := n'
  case state.pred {
    option.Some(p) -> {
      // TODO: Handle wrap around
      let in_range = in_open_interval(n0.id, p.id, state.id)
      // n's id is between predecessor and this node
      case in_range {
        True -> {
          let new_state =
            StateHolder(
              state.id,
              state.self_subject,
              option.Some(n0),
              state.finger_table,
              state.storage,
              state.request_num,
              state.max_num,
              state.super,
            )
          new_state
        }
        _ -> state
      }
    }
    // predecessor is nil
    option.None -> {
      let new_state =
        StateHolder(
          state.id,
          state.self_subject,
          option.Some(n0),
          state.finger_table,
          state.storage,
          state.request_num,
          state.max_num,
          state.super,
        )
      new_state
    }
  }
}

// // called periodically. refreshes finger table entries.
// // next stores the index of the finger to fix
fn fix_fingers(next: Int, m: Int, state: StateHolder(e)) -> StateHolder(e) {
  //     next := next + 1
  //     if next > m then
  //         next := 1
  //     finger[next] := find_successor(n+2next-1);
  let new_next = next + 1
  let final_next = case int.compare(new_next, m) {
    order.Gt -> 1
    _ -> new_next
  }

  let loc = int.power(2, int.to_float(final_next - 1))
  let final_loc = case loc {
    Ok(v) -> float.round(v)
    _ -> 0
  }
  // TODO: Change table locations to either 1234 or 1248...
  let new_finger = find_successor(state, state.id + final_loc, 0)
  let new_table = dict.insert(state.finger_table, final_next, new_finger)
  let new_state =
    StateHolder(
      state.id,
      state.self_subject,
      state.pred,
      new_table,
      state.storage,
      state.request_num,
      state.max_num,
      state.super,
    )
  new_state
}

// called periodically. checks whether predecessor has failed.
fn check_predecessor() {
  todo
  //  if (predecessor has failed)
  //  predecessor = nil;
}

fn send_requests(from: NodeInfo(e), num_requests: Int) {
  todo
  //process.sleep(1000)

  //Send requests
  case int.modulo(num_requests, 2) {
    Ok(0) -> {
      let result =
        process.call(from.subject, 1000, AddKeyToRing(num_requests, 0.0, _, 0))
      Nil
    }
    _ -> {
      process.call(from.subject, 1000, FindSuccessor(num_requests - 1, _, 0))
      Nil
    }
  }

  send_requests(from, num_requests - 1)
}

pub fn node_handler(
  state: StateHolder(e),
  message: NodeOperation(e),
) -> actor.Next(StateHolder(e), NodeOperation(e)) {
  case message {
    AddSelfInfo(info) -> {
      let new_state =
        StateHolder(
          state.id,
          option.Some(info),
          state.pred,
          state.finger_table,
          state.storage,
          state.request_num,
          state.max_num,
          state.super,
        )
      actor.continue(new_state)
    }
    SearchKey(key, reply_with, jump) -> {
      let node_with_key = find_successor(state, key, jump)
      let node_state = process.call(node_with_key.subject, 1000, GetState)
      let value = dict.get(node_state.storage, key)
      case value {
        Ok(v) -> {
          process.send(reply_with, v)
          actor.continue(state)
        }
        _ -> {
          // Key not found
          process.send(reply_with, 0.0)
          actor.continue(state)
        }
      }
    }
    AddKeyToRing(key, value, reply, jump) -> {
      let node_with_key = find_successor(state, key, jump)
      process.send(node_with_key.subject, AddKeyToStorage(key, value))
      process.send(reply, jump)
      actor.continue(state)
    }
    AddKeyToStorage(key, value) -> {
      let new_storage = dict.insert(state.storage, key, value)
      let new_state =
        StateHolder(
          state.id,
          state.self_subject,
          state.pred,
          state.finger_table,
          new_storage,
          state.request_num,
          state.max_num,
          state.super,
        )
      actor.continue(new_state)
    }
    FindSuccessor(id, reply_with, jump) -> {
      case state.self_subject {
        option.Some(_subject) -> {
          let result = find_successor(state, id, jump)
          process.send(reply_with, result)
          actor.continue(state)
        }
        option.None -> {
          // Should not happen
          actor.continue(state)
        }
      }
    }
    CreateChordRing -> {
      case state.self_subject {
        option.Some(subject) -> {
          let new_state = create(state, subject)
          actor.continue(new_state)
        }
        option.None -> {
          // Should not happen
          actor.continue(state)
        }
      }
    }
    Join(existing_chord_node) -> {
      let new_state = join(state, existing_chord_node)
      actor.continue(new_state)
    }
    GetState(caller) -> {
      process.send(caller, state)
      actor.continue(state)
    }
    Stabilize -> {
      stabilize(state)
      actor.continue(state)
    }
    Notify(potential_predecessor) -> {
      let new_state = notify(state, potential_predecessor)
      // new state with updated predecessor
      actor.continue(new_state)
    }
    FixFingers -> {
      let m = 4
      // TODO: Change to 8 later
      let new_state = fix_fingers(0, m, state)
      actor.continue(new_state)
    }
    CheckPredecessor -> {
      check_predecessor()
      actor.continue(state)
    }
    HopNumber(reply, number) -> {
      actor.send(reply, number)
      actor.continue(state)
    }
    Finish -> {
      process.send(state.super, Finish)
      actor.continue(state)
    }
  }
}
