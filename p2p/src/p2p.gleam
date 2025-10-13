import argv
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import nodes

pub fn waiter(
  nodes: List(#(Int, process.Subject(nodes.NodeOperation(e)))),
  subject: process.Subject(nodes.NodeOperation(e)),
) {
  // echo nodes
  case list.first(nodes) {
    Ok(sub) -> {
      // process.receive_forever(pair.second(sub))
      process.receive_forever(subject)
      //io.println("node has finished")
      let new_nodes = case nodes {
        [_, ..rest] -> rest
        _ -> []
      }
      waiter(new_nodes, subject)
    }
    _ -> {
      io.println("All nodes have finished")
    }
  }
}

pub fn main() {
  case argv.load().arguments {
    ["project3", first, second] -> {
      case int.parse(first) {
        Ok(result) -> {
          let n = result
          case int.parse(second) {
            Ok(result) -> {
              io.println(
                "initializing "
                <> first
                <> " peers that make "
                <> second
                <> " requests each",
              )
              //TODO
              let id = 0
              let pred = 0
              let max_requests = result
              let max_nodes = n
              let super = process.new_subject()
              let all_nodes =
                nodes.initialize_actors(
                  id,
                  pred,
                  0,
                  max_requests,
                  max_nodes,
                  dict.new(),
                  super,
                )
              io.println("All nodes initialized")
              waiter(dict.to_list(all_nodes), super)

              //

              //call on super to start nodes with (numNodes and numRequests)

              Nil
            }
            _ -> io.println("numRequests is not int")
          }
        }
        _ -> io.println("numNodes is not int")
      }
    }
    _ -> io.println("usage: gleam run project3 <numNodes> <numRequests>")
  }
}
