import argv
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import nodes

//https://bitbucket.org/felixy12/cos518_project/src/master/Chord_Python/src/

pub fn waiter(nodes: List(process.Subject(nodes.NodeOperation(e)))) {
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
