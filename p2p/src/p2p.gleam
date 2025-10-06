import argv
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/otp/actor

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
            }
            _ -> io.println("k is not int")
          }
        }
        _ -> io.println("n is not int")
      }
    }
    _ -> io.println("usage: gleam run project3 <numNodes> <numRequests>")
  }
}
