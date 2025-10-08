import argv
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import nodes

//https://bitbucket.org/felixy12/cos518_project/src/master/Chord_Python/src_2/

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

              let subject = process.new_subject()
              let assert Ok(actor) =
                actor.new([])
                |> actor.on_message(nodes.super_handler)
                |> actor.start
              let sub = actor.data

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
